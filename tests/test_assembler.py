"""End-to-end tests for the assembler command-line interface."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ASSEMBLER = REPOSITORY_ROOT / "assembler.py"
CPU_ASSEMBLER_TESTBENCH = REPOSITORY_ROOT / "tb" / "integration" / "assembler_cpu_tb.v"


# Each entry is an assembly statement, its exact emitted word, and the fields
# the RTL decoder is expected to expose as
# (opcode, dst_reg, src_reg_a, src_reg_b, immediate, address).
VALID_INSTRUCTION_CASES = (
    ("ldi r8 511", "0FFF", (0x0, 0x7, 0x0, 0x0, 0x1FF, 0x000)),
    ("mov r8 r1", "1E00", (0x1, 0x7, 0x0, 0x0, 0x000, 0x000)),
    ("add r8 r7 r6", "2FA8", (0x2, 0x7, 0x6, 0x5, 0x000, 0x000)),
    ("sub r7 r6 r5", "3D60", (0x3, 0x6, 0x5, 0x4, 0x000, 0x000)),
    ("and r6 r5 r4", "4B18", (0x4, 0x5, 0x4, 0x3, 0x000, 0x000)),
    ("or r5 r4 r3", "58D0", (0x5, 0x4, 0x3, 0x2, 0x000, 0x000)),
    ("xor r4 r3 r2", "6688", (0x6, 0x3, 0x2, 0x1, 0x000, 0x000)),
    ("shl r3 r2 r1", "7440", (0x7, 0x2, 0x1, 0x0, 0x000, 0x000)),
    ("shr r2 r1 r8", "8238", (0x8, 0x1, 0x0, 0x7, 0x000, 0x000)),
    ("mul r1 r8 r7", "91F0", (0x9, 0x0, 0x7, 0x6, 0x000, 0x000)),
    ("load r8 r7", "AF80", (0xA, 0x7, 0x0, 0x6, 0x000, 0x000)),
    ("store r8 r1", "BE00", (0xB, 0x0, 0x7, 0x0, 0x000, 0x000)),
    ("vload v8 r7", "AFA0", (0xA, 0x7, 0x0, 0x6, 0x000, 0x000)),
    ("vstore v8 r1", "BE20", (0xB, 0x0, 0x7, 0x0, 0x000, 0x000)),
    ("vadd v8 v7 v6", "F3F5", (0xF, 0x5, 0x7, 0x6, 0x000, 0x000)),
    ("vsub v7 v6 v5", "F5AC", (0xF, 0x4, 0x6, 0x5, 0x000, 0x000)),
    ("vmul v1 v8 v7", "F63E", (0xF, 0x6, 0x0, 0x7, 0x000, 0x000)),
    ("vdot v8 v7 r6", "F9F5", (0xF, 0x5, 0x7, 0x6, 0x000, 0x000)),
    ("cmp r8 r1", "CE00", (0xC, 0x0, 0x7, 0x0, 0x000, 0x000)),
    ("jmp 511", "D1FF", (0xD, 0x0, 0x0, 0x0, 0x000, 0x1FF)),
    ("je 0", "E000", (0xE, 0x0, 0x0, 0x0, 0x000, 0x000)),
    ("halt_or_vector", "F000", (0xF, 0x0, 0x0, 0x0, 0x000, 0x000)),
)


def decoder_fields(word: int) -> tuple[int, int, int, int, int, int]:
    """Decode a word independently using the field layout in rtl/cpu/decoder.v."""

    opcode = (word >> 12) & 0xF
    dst_reg = src_reg_a = src_reg_b = immediate = address = 0

    if opcode in range(0x2, 0xA):
        dst_reg = (word >> 9) & 0x7
        src_reg_a = (word >> 6) & 0x7
        src_reg_b = (word >> 3) & 0x7
    elif opcode == 0xA:
        dst_reg = (word >> 9) & 0x7
        src_reg_b = (word >> 6) & 0x7
    elif opcode == 0xB:
        src_reg_a = (word >> 9) & 0x7
        src_reg_b = (word >> 6) & 0x7
    elif opcode == 0xC:
        src_reg_a = (word >> 9) & 0x7
        src_reg_b = (word >> 6) & 0x7
    elif opcode == 0x1:
        dst_reg = (word >> 9) & 0x7
        src_reg_a = (word >> 6) & 0x7
    elif opcode == 0x0:
        dst_reg = (word >> 9) & 0x7
        immediate = word & 0x1FF
    elif opcode in (0xD, 0xE):
        address = word & 0x1FF
    elif opcode == 0xF and ((word >> 9) & 0x7) in (0x1, 0x2, 0x3, 0x4):
        dst_reg = word & 0x7
        src_reg_a = (word >> 6) & 0x7
        src_reg_b = (word >> 3) & 0x7

    return opcode, dst_reg, src_reg_a, src_reg_b, immediate, address


class AssemblerTestSupport:
    def setUp(self) -> None:
        self._temporary_directory = tempfile.TemporaryDirectory()
        self.workspace = Path(self._temporary_directory.name)

    def tearDown(self) -> None:
        self._temporary_directory.cleanup()

    def run_assembler(
        self, source: str, workspace: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        workspace = workspace or self.workspace
        workspace.mkdir(parents=True, exist_ok=True)
        source_path = workspace / "program.asm"
        source_path.write_text(source, encoding="utf-8")

        environment = os.environ.copy()
        # Keep assembler scratch files inside the per-test directory, including
        # scratch files left behind by an intentionally failing assembly.
        environment["TMPDIR"] = str(workspace)

        return subprocess.run(
            [sys.executable, str(ASSEMBLER), str(source_path)],
            cwd=workspace,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def assemble(self, source: str, workspace: Path | None = None) -> list[str]:
        workspace = workspace or self.workspace
        result = self.run_assembler(source, workspace)
        self.assertEqual(
            result.returncode,
            0,
            msg=f"assembler failed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )
        output_path = workspace / "program.hex"
        self.assertTrue(output_path.is_file(), "assembler did not produce program.hex")
        return output_path.read_text(encoding="utf-8").splitlines()

    def assert_assembly_fails(self, source: str, workspace: Path | None = None) -> None:
        workspace = workspace or self.workspace
        result = self.run_assembler(source, workspace)
        self.assertNotEqual(
            result.returncode,
            0,
            msg=f"assembler unexpectedly succeeded:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )


class AssemblerCliTests(AssemblerTestSupport, unittest.TestCase):
    def test_every_instruction_encodes_to_the_decoder_field_layout(self) -> None:
        words = self.assemble("\n".join(case[0] for case in VALID_INSTRUCTION_CASES))
        self.assertEqual(words, [case[1] for case in VALID_INSTRUCTION_CASES])

        for (source, expected_word, expected_fields), emitted_word in zip(
            VALID_INSTRUCTION_CASES, words, strict=True
        ):
            with self.subTest(instruction=source):
                word = int(emitted_word, 16)
                self.assertEqual(word, int(expected_word, 16))
                self.assertEqual(decoder_fields(word), expected_fields)

    def test_arbitrary_spaces_and_tabs_are_ignored(self) -> None:
        words = self.assemble(
            " \t  ldi\t r1   7 \t \n"
            "  add  r2\t r1    r1\t\n"
            "\t halt_or_vector \t  \n"
        )

        self.assertEqual(words, ["0007", "2200", "F000"])

    def test_blank_lines_are_ignored(self) -> None:
        words = self.assemble("\n\t  \nldi r1 7\n\n  \t\nhalt_or_vector\n\n")

        self.assertEqual(words, ["0007", "F000"])

    def test_hash_comments_are_ignored(self) -> None:
        words = self.assemble(
            "# A full-line comment\n"
            "  # Leading whitespace before a comment is allowed\n"
            "ldi r1 7 # An inline comment\n"
            "add r2 r1 r1# A comment need not have leading whitespace\n"
            "halt_or_vector # Done\n"
        )

        self.assertEqual(words, ["0007", "2200", "F000"])

    def test_each_nonblank_line_produces_one_word(self) -> None:
        source = "ldi r1 1\nhalt_or_vector\njmp 0\nhalt_or_vector\n"
        words = self.assemble(source)

        self.assertEqual(len(words), 4)
        self.assertEqual(words, ["0001", "F000", "D000", "F000"])

    def test_unknown_mnemonics_invalid_characters_and_wrong_operand_counts_fail(self) -> None:
        invalid_programs = {
            "unknown mnemonic": "unknown r1 r2\n",
            "invalid character": "ldi r1 12!\n",
            "missing operand": "add r1 r2\n",
            "extra operand": "halt_or_vector r1\n",
            "legacy halt mnemonic": "halt\n",
        }

        for description, source in invalid_programs.items():
            with self.subTest(reason=description):
                self.assert_assembly_fails(source)
                self.assertFalse((self.workspace / "program.hex").exists())

    def test_register_names_are_one_based_and_case_insensitive(self) -> None:
        words = self.assemble("ldi r1 0\nldi r8 0\nldi R1 0\nldi R8 0\n")

        self.assertEqual(words, ["0000", "0E00", "0000", "0E00"])

    def test_r0_and_r9_are_rejected(self) -> None:
        for register in ("r0", "r9"):
            with self.subTest(register=register):
                self.assert_assembly_fails(f"ldi {register} 0\n")

    def test_immediate_and_address_boundaries_are_accepted(self) -> None:
        words = self.assemble("ldi r1 0\nldi r1 511\njmp 0\nje 511\n")

        self.assertEqual(words, ["0000", "01FF", "D000", "E1FF"])

    def test_out_of_range_immediates_and_addresses_are_rejected(self) -> None:
        for operand_kind, source in (
            ("immediate -1", "ldi r1 -1\n"),
            ("immediate 512", "ldi r1 512\n"),
            ("address -1", "jmp -1\n"),
            ("address 512", "jmp 512\n"),
        ):
            with self.subTest(operand_kind=operand_kind):
                self.assert_assembly_fails(source)

    def test_decimal_operands_are_accepted(self) -> None:
        words = self.assemble("ldi r1 42\njmp 42\n")

        self.assertEqual(words, ["002A", "D02A"])

    def test_memory_operands_require_registers(self) -> None:
        words = self.assemble(
            "load r2 r3\n"
            "store r4 r5\n"
            "vload v2 r3\n"
            "vstore v4 r5\n"
        )

        self.assertEqual(words, ["A280", "B700", "A2A0", "B720"])

        for source in (
            "load r1 42\n",
            "store r1 42\n",
            "load r1 [r2]\n",
            "store r1 [r2]\n",
            "store r1 r0\n",
            "load r1 r9\n",
            "vload r1 r2\n",
            "vstore r1 r2\n",
            "vload v1 42\n",
            "vstore v1 r0\n",
            "vload v9 r1\n",
            "vadd v1 v2 r3\n",
            "vsub v1 v9 v2\n",
            "vmul v1 v2 v0\n",
            "vdot v1 v2 v3\n",
            "vdot v1 r2 r3\n",
        ):
            with self.subTest(source=source):
                self.assert_assembly_fails(source)

    def test_nondecimal_and_malformed_numeric_tokens_are_rejected(self) -> None:
        invalid_operands = (
            ("hexadecimal", "ldi r1 0x10\n"),
            ("binary", "jmp 0b10\n"),
            ("negative signed", "ldi r1 -1\n"),
            ("positive signed", "jmp +1\n"),
            ("malformed", "ldi r1 12x\n"),
        )

        for kind, source in invalid_operands:
            with self.subTest(kind=kind):
                self.assert_assembly_fails(source)

    def test_mnemonic_case_does_not_change_output(self) -> None:
        lowercase_source = "\n".join(case[0] for case in VALID_INSTRUCTION_CASES)
        uppercase_source = lowercase_source.upper()

        lowercase_words = self.assemble(lowercase_source, self.workspace / "lowercase")
        uppercase_words = self.assemble(uppercase_source, self.workspace / "uppercase")

        self.assertEqual(uppercase_words, lowercase_words)

    def test_512_instructions_are_accepted_and_513_are_rejected(self) -> None:
        accepted_workspace = self.workspace / "accepted"
        words = self.assemble("halt_or_vector\n" * 512, accepted_workspace)
        self.assertEqual(len(words), 512)
        self.assertTrue(all(word == "F000" for word in words))

        rejected_workspace = self.workspace / "rejected"
        self.assert_assembly_fails("halt_or_vector\n" * 513, rejected_workspace)
        self.assertFalse((rejected_workspace / "program.hex").exists())

    def test_failure_does_not_publish_a_partial_hex_file(self) -> None:
        self.assert_assembly_fails("ldi r1 7\nunknown r1 r2\n")

        self.assertFalse(
            (self.workspace / "program.hex").exists(),
            "a failed assembly must not publish the valid first instruction as program.hex",
        )


class AssemblerCpuIntegrationTests(AssemblerTestSupport, unittest.TestCase):
    def test_generated_hex_executes_in_the_cpu_via_readmemh(self) -> None:
        self.assemble(
            "ldi r1 7\n"
            "ldi r2 5\n"
            "add r3 r1 r2\n"
            "ldi r4 400\n"
            "store r3 r4\n"
            "load r5 r4\n"
            "ldi r6 401\n"
            "store r5 r6\n"
            "ldi r7 100\n"
            "vload v1 r7\n"
            "ldi r6 402\n"
            "store r1 r6\n"
            "ldi r7 110\n"
            "vload v2 r7\n"
            "vadd v1 v2 v3\n"
            "vsub v1 v2 v4\n"
            "vmul v1 v2 v5\n"
            "vdot v1 v2 r3\n"
            "ldi r6 403\n"
            "store r3 r6\n"
            "ldi r7 200\n"
            "vstore v1 r7\n"
            "ldi r7 300\n"
            "vstore v3 r7\n"
            "ldi r7 310\n"
            "vstore v4 r7\n"
            "ldi r7 320\n"
            "vstore v5 r7\n"
            "halt_or_vector\n"
        )

        iverilog = shutil.which("iverilog")
        vvp = shutil.which("vvp")
        self.assertIsNotNone(iverilog, "the CPU integration test requires iverilog")
        self.assertIsNotNone(vvp, "the CPU integration test requires vvp")

        simulator = self.workspace / "assembler_cpu_tb.vvp"
        include_directories = (
            REPOSITORY_ROOT / "rtl" / "include",
            REPOSITORY_ROOT / "rtl" / "lib",
            REPOSITORY_ROOT / "rtl" / "cpu",
            REPOSITORY_ROOT / "rtl" / "memory",
            REPOSITORY_ROOT / "rtl" / "top",
        )
        compile_result = subprocess.run(
            [
                iverilog,
                "-g2012",
                *(f"-I{directory}" for directory in include_directories),
                "-o",
                str(simulator),
                str(CPU_ASSEMBLER_TESTBENCH),
            ],
            cwd=self.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(
            compile_result.returncode,
            0,
            msg=(
                "failed to compile assembler CPU integration testbench:\n"
                f"stdout:\n{compile_result.stdout}\nstderr:\n{compile_result.stderr}"
            ),
        )

        simulation_result = subprocess.run(
            [vvp, str(simulator)],
            cwd=self.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(
            simulation_result.returncode,
            0,
            msg=(
                "assembler-generated program failed in the CPU testbench:\n"
                f"stdout:\n{simulation_result.stdout}\nstderr:\n{simulation_result.stderr}"
            ),
        )
        self.assertIn("assembler_cpu_tb passed", simulation_result.stdout)


if __name__ == "__main__":
    unittest.main()
