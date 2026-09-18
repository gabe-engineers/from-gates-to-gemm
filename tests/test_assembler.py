"""End-to-end tests for the assembler and its CPU output."""

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
CPU_TESTBENCH = REPOSITORY_ROOT / "tb" / "integration" / "assembler_cpu_tb.sv"

VALID_INSTRUCTION_CASES = (
    ("ldi r8 255", "07FF", (0x00, 7, 0, 0, 0x00FF, 0)),
    ("mov r8 r1", "0F00", (0x01, 7, 0, 0, 0, 0)),
    ("add r8 r7 r6", "17D4", (0x02, 7, 6, 5, 0, 0)),
    ("sub r7 r6 r5", "1EB0", (0x03, 6, 5, 4, 0, 0)),
    ("and r6 r5 r4", "258C", (0x04, 5, 4, 3, 0, 0)),
    ("or r5 r4 r3", "2C68", (0x05, 4, 3, 2, 0, 0)),
    ("xor r4 r3 r2", "3344", (0x06, 3, 2, 1, 0, 0)),
    ("shl r3 r2 r1", "3A20", (0x07, 2, 1, 0, 0, 0)),
    ("shr r2 r1 r8", "411C", (0x08, 1, 0, 7, 0, 0)),
    ("mul r1 r8 r7", "48F8", (0x09, 0, 7, 6, 0, 0)),
    ("load r8 r7", "57C0", (0x0A, 7, 0, 6, 0, 0)),
    ("store r8 r1", "5F00", (0x0B, 0, 0, 7, 0, 0)),
    ("cmp r8 r1", "6700", (0x0C, 0, 7, 0, 0, 0)),
    ("jmp 2047", "6FFF", (0x0D, 0, 0, 0, 0, 0x07FF)),
    ("je 0", "7000", (0x0E, 0, 0, 0, 0, 0)),
    ("halt", "7800", (0x0F, 0, 0, 0, 0, 0)),
    ("vld v8 r7", "87C0", (0x10, 7, 0, 6, 0, 0)),
    ("vst r1 v8", "88E0", (0x11, 0, 7, 0, 0, 0)),
    ("vadd v8 v7 v6", "97D4", (0x12, 7, 6, 5, 0, 0)),
    ("vsub v7 v6 v5", "9EB0", (0x13, 6, 5, 4, 0, 0)),
    ("vmul v1 v8 v7", "A0F8", (0x14, 0, 7, 6, 0, 0)),
    ("vdot r6 v8 v7", "ADF8", (0x15, 5, 7, 6, 0, 0)),
    ("lui r8 255", "B7FF", (0x16, 7, 0, 0, 0xFF00, 0)),
    ("tid r8", "BF00", (0x17, 7, 0, 0, 0, 0)),
)


def decoder_fields(word: int) -> tuple[int, int, int, int, int, int]:
    opcode = (word >> 11) & 0x1F
    dst = src_a = src_b = immediate = address = 0
    if opcode in (*range(0x02, 0x0A), *range(0x12, 0x16)):
        dst, src_a, src_b = (word >> 8) & 7, (word >> 5) & 7, (word >> 2) & 7
    elif opcode in (0x0A, 0x10):
        dst, src_b = (word >> 8) & 7, (word >> 5) & 7
    elif opcode in (0x0B, 0x11):
        src_b, src_a = (word >> 8) & 7, (word >> 5) & 7
    elif opcode == 0x0C:
        src_a, src_b = (word >> 8) & 7, (word >> 5) & 7
    elif opcode == 0x01:
        dst, src_a = (word >> 8) & 7, (word >> 5) & 7
    elif opcode == 0x00:
        dst, immediate = (word >> 8) & 7, word & 0xFF
    elif opcode == 0x16:
        dst, immediate = (word >> 8) & 7, (word & 0xFF) << 8
    elif opcode == 0x17:
        dst = (word >> 8) & 7
    elif opcode in (0x0D, 0x0E):
        address = word & 0x7FF
    return opcode, dst, src_a, src_b, immediate, address


class AssemblerTestSupport:
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.workspace = Path(self.temporary_directory.name)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_assembler(self, source: str, workspace: Path | None = None):
        workspace = workspace or self.workspace
        workspace.mkdir(parents=True, exist_ok=True)
        source_path = workspace / "program.asm"
        source_path.write_text(source, encoding="utf-8")
        environment = os.environ.copy()
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
        self.assertEqual(result.returncode, 0, result.stderr)
        return (workspace / "program.hex").read_text(encoding="utf-8").splitlines()

    def assert_fails(self, source: str) -> None:
        result = self.run_assembler(source)
        self.assertNotEqual(result.returncode, 0, "assembler unexpectedly succeeded")


class AssemblerCliTests(AssemblerTestSupport, unittest.TestCase):
    def test_every_instruction_encoding_and_decoder_layout(self) -> None:
        words = self.assemble("\n".join(case[0] for case in VALID_INSTRUCTION_CASES))
        self.assertEqual(words, [case[1] for case in VALID_INSTRUCTION_CASES])
        for (_, expected_word, expected_fields), emitted in zip(
            VALID_INSTRUCTION_CASES, words, strict=True
        ):
            self.assertEqual(int(emitted, 16), int(expected_word, 16))
            self.assertEqual(decoder_fields(int(emitted, 16)), expected_fields)

    def test_whitespace_comments_case_and_jz_alias(self) -> None:
        words = self.assemble(
            " # comment\n\tLDI R1 7 # value\n  JZ 42\n\tHALT\n"
        )
        self.assertEqual(words, ["0007", "702A", "7800"])

    def test_immediate_and_jump_boundaries(self) -> None:
        self.assertEqual(
            self.assemble("ldi r1 0\nldi r1 255\nlui r1 0\nlui r1 255\njmp 0\nje 2047\n"),
            ["0000", "00FF", "B000", "B0FF", "6800", "77FF"],
        )
        for source in (
            "ldi r1 256\n",
            "ldi r1 -1\n",
            "lui r1 256\n",
            "lui r1 -1\n",
            "jmp 2048\n",
            "jmp -1\n",
        ):
            with self.subTest(source=source):
                self.assert_fails(source)

    def test_register_types_operand_counts_and_unsupported_opcodes(self) -> None:
        invalid = (
            "ldi r0 0\n",
            "vld r1 r2\n",
            "vst v1 r2\n",
            "vadd v1 v2 r3\n",
            "vdot v1 v2 v3\n",
            "store r1\n",
            "glaunch r1 r2 r3\n",
            "gwait\n",
            "tid r0\n",
            "halt_or_vector\n",
        )
        for source in invalid:
            with self.subTest(source=source):
                self.assert_fails(source)

    def test_program_size_is_physical_ram_capacity(self) -> None:
        words = self.assemble("halt\n" * 512)
        self.assertEqual(len(words), 512)
        self.assertTrue(all(word == "7800" for word in words))
        self.assert_fails("halt\n" * 513)


class AssemblerCpuIntegrationTests(AssemblerTestSupport, unittest.TestCase):
    def test_generated_hex_executes_in_cpu(self) -> None:
        self.assemble(
            "ldi r1 7\n"
            "ldi r2 5\n"
            "add r3 r1 r2\n"
            "lui r4 1\n"
            "ldi r6 144\n"
            "or r4 r4 r6\n"        # 400
            "store r4 r3\n"
            "load r5 r4\n"
            "ldi r6 1\n"
            "add r6 r4 r6\n"       # 401
            "store r6 r5\n"
            "ldi r7 100\n"
            "vld v1 r7\n"
            "ldi r6 2\n"
            "add r6 r4 r6\n"       # 402
            "store r6 r1\n"
            "ldi r7 110\n"
            "vld v2 r7\n"
            "vadd v3 v1 v2\n"
            "vsub v4 v1 v2\n"
            "vmul v5 v1 v2\n"
            "vdot r3 v1 v2\n"
            "ldi r6 3\n"
            "add r6 r4 r6\n"       # 403
            "store r6 r3\n"
            "ldi r7 200\n"
            "vst r7 v1\n"
            "ldi r7 100\n"
            "sub r7 r4 r7\n"       # 300
            "vst r7 v3\n"
            "ldi r6 10\n"
            "add r7 r7 r6\n"       # 310
            "vst r7 v4\n"
            "add r7 r7 r6\n"       # 320
            "vst r7 v5\n"
            "halt\n"
        )

        simulator = self.workspace / "assembler_cpu_tb.vvp"
        include_dirs = ("rtl/include", "rtl/lib", "rtl/cpu", "rtl/memory", "rtl/top")
        compile_result = subprocess.run(
            [
                shutil.which("iverilog") or "iverilog",
                "-g2012",
                *(f"-I{REPOSITORY_ROOT / path}" for path in include_dirs),
                "-o",
                str(simulator),
                str(CPU_TESTBENCH),
            ],
            cwd=self.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
        run_result = subprocess.run(
            [shutil.which("vvp") or "vvp", str(simulator)],
            cwd=self.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(run_result.returncode, 0, run_result.stdout + run_result.stderr)


if __name__ == "__main__":
    unittest.main()
