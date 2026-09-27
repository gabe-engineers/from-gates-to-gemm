"""End-to-end tests for the checked-in dot-product programs.

Every program in ``programs/dot-product`` gets its own test, assembled with
its sibling ``.data`` image and run through the chip-level ``program_tb``. The
data image holds ``mem[100]=N``, ``mem[101]=V1 base``, and ``mem[102]=V2
base``; the test computes the dot product in Python from the same image and
asserts the value the program leaves at ``mem[511]``. The accumulator is
16-bit, so the reference is taken modulo 2**16.

Programs listed in ``REQUIRED_PROGRAMS`` must assemble, so a regression there
fails the suite; any other program that does not assemble yet is reported as
skipped.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
PROGRAM_TB = REPOSITORY_ROOT / "tb" / "integration" / "system" / "program_tb.sv"
ASSEMBLER = REPOSITORY_ROOT / "tools" / "assembler.py"
RTL_FILELIST = REPOSITORY_ROOT / "rtl" / "filelists" / "chip.f"

REQUIRED_PROGRAMS = ("scalar.asm", "simd.asm", "simt.asm")
DATA_BASE = 100
RESULT_ADDRESS = 511
WORD_PATTERN = re.compile(r"\s*([0-9A-Fa-f]+)")


def load_data_image(path: Path) -> dict[int, int]:
    memory: dict[int, int] = {}
    address = DATA_BASE
    for line in path.read_text(encoding="utf-8").splitlines():
        match = WORD_PATTERN.match(line)
        if match:
            memory[address] = int(match.group(1), 16)
            address += 1
    return memory


def reference_dot_product(image: dict[int, int]) -> int:
    n = image[100]
    v1_base = image[101]
    v2_base = image[102]
    total = sum(image[v1_base + k] * image[v2_base + k] for k in range(n))
    return total & 0xFFFF


class DotProductTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._temporary_directory = tempfile.TemporaryDirectory()
        cls.workspace = Path(cls._temporary_directory.name)
        cls.program_hex = cls.workspace / "program.hex"
        cls.simulator = cls.workspace / "program_tb.vvp"
        compile_result = subprocess.run(
            [
                shutil.which("iverilog") or "iverilog",
                "-g2012",
                f"-I{REPOSITORY_ROOT / 'rtl' / 'include'}",
                "-f",
                str(RTL_FILELIST),
                "-o",
                str(cls.simulator),
                str(PROGRAM_TB),
            ],
            cwd=REPOSITORY_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if compile_result.returncode != 0:
            raise AssertionError(compile_result.stderr)

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temporary_directory.cleanup()

    def run_and_read(self, data_file: Path, address: int) -> int:
        result = subprocess.run(
            [
                shutil.which("vvp") or "vvp",
                str(self.simulator),
                f"+PROGRAM={self.program_hex}",
                f"+DATA={data_file}",
                f"+RESULT={address}",
            ],
            cwd=self.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for line in result.stdout.splitlines():
            if line.startswith(f"mem[{address}] ="):
                return int(line.split("= ")[1].split(" ")[0], 16)
        self.fail(f"runner did not report RAM word {address}")

    def check_program(self, program: Path) -> None:
        assemble_result = subprocess.run(
            [sys.executable, str(ASSEMBLER), str(program)],
            cwd=self.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        if assemble_result.returncode != 0:
            message = (assemble_result.stderr or "").strip().splitlines()
            reason = f"{program.name} does not assemble: {message[-1] if message else ''}"
            if program.name in REQUIRED_PROGRAMS:
                self.fail(reason)
            self.skipTest(reason)

        data_file = program.with_suffix(".data")
        self.assertTrue(data_file.is_file(), f"missing data image {data_file}")
        image = load_data_image(data_file)
        expected = reference_dot_product(image)
        self.assertEqual(
            self.run_and_read(data_file, RESULT_ADDRESS),
            expected,
            f"{program.name}: mem[{RESULT_ADDRESS}] does not match the reference",
        )


def _make_program_test(program: Path):
    def test(self: DotProductTests) -> None:
        self.check_program(program)

    test.__name__ = f"test_{program.stem}_matches_reference"
    test.__doc__ = f"Run the dot-product case against {program.name}."
    return test


_DOT_PRODUCT_PROGRAMS = sorted((REPOSITORY_ROOT / "programs" / "dot-product").glob("*.asm"))
for _program in _DOT_PRODUCT_PROGRAMS:
    _test = _make_program_test(_program)
    setattr(DotProductTests, _test.__name__, _test)


class DotProductDiscoveryTests(unittest.TestCase):
    def test_at_least_one_dot_product_program_exists(self) -> None:
        self.assertTrue(_DOT_PRODUCT_PROGRAMS, "no dot-product programs found")

    def test_required_dot_product_programs_exist(self) -> None:
        names = {program.name for program in _DOT_PRODUCT_PROGRAMS}
        for required in REQUIRED_PROGRAMS:
            with self.subTest(program=required):
                self.assertIn(required, names, f"required dot-product program {required} is missing")


if __name__ == "__main__":
    unittest.main()
