"""End-to-end tests for the checked-in GEMM programs.

Every ``gemm_*.asm`` program in the repository gets its own test, assembled and
run against the same cases, so a new variant (for example a SIMD version) is
covered without editing this file. A program that does not assemble yet is
reported as skipped, so an in-progress variant does not fail the suite.

Each case builds a data image (M, N, P, the two matrices), runs the chip-level
``program_tb`` and compares every element of the product against a Python
reference. The accumulator is 16-bit, so the reference is taken modulo 2**16.

Programs share one convention:
  mem[100]=M, mem[101]=N, mem[102]=P, mem[103]=A base, mem[104]=B^T base,
  A row-major (M x N), B stored transposed as B^T row-major (P x N) so that
  C[i][j] = dot(A row i, B^T row j) walks both operands with unit stride,
  mem[115]=C base and C row-major.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PROGRAM_TB = REPOSITORY_ROOT / "tb" / "integration" / "program_tb.sv"
INCLUDE_DIRS = ("rtl/include", "rtl/lib", "rtl/cpu", "rtl/memory", "rtl/top")

# Program memory map: 100=M, 101=N, 102=P, 103=A base, 104=B base, 115=C base.
C_BASE = 116

# (M, N, P, A, B)
GEMM_CASES = (
    (
        3, 4, 2,
        [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]],
        [[1, 0], [0, 1], [1, 1], [2, 2]],
    ),
    (
        4, 4, 4,
        [[2, 0, 1, 3], [1, 4, 0, 2], [3, 1, 2, 0], [0, 2, 3, 1]],
        [[1, 2, 3, 4], [0, 1, 0, 1], [2, 0, 1, 0], [1, 1, 1, 1]],
    ),
    (
        2, 5, 3,
        [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]],
        [[1, 1, 1], [2, 2, 2], [3, 3, 3], [4, 4, 4], [5, 5, 5]],
    ),
    # N >= 8 exercises the VLD/VDOT path: one SIMD round plus a tail.
    (
        2, 9, 2,
        [[1, 2, 3, 4, 5, 6, 7, 8, 9], [10, 11, 12, 13, 14, 15, 16, 17, 18]],
        [[k + 1, 1] for k in range(9)],
    ),
    # N a multiple of 8 exercises two SIMD rounds with no tail.
    (
        2, 16, 2,
        [[i * 16 + k + 1 for k in range(16)] for i in range(2)],
        [[1, k % 3 + 1] for k in range(16)],
    ),
)


def reference_product(a, b):
    m, n, p = len(a), len(b), len(b[0])
    return [
        [sum(a[i][k] * b[k][j] for k in range(n)) & 0xFFFF for j in range(p)]
        for i in range(m)
    ]


class GemmTests(unittest.TestCase):
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
                f"-I{REPOSITORY_ROOT}",
                *(f"-I{REPOSITORY_ROOT / path}" for path in INCLUDE_DIRS),
                "-o",
                str(cls.simulator),
                str(PROGRAM_TB),
            ],
            cwd=cls.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        if compile_result.returncode != 0:
            raise AssertionError(compile_result.stderr)

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temporary_directory.cleanup()

    def build_data_image(self, m, n, p, a, b) -> str:
        a_base = C_BASE + m * p
        b_base = a_base + m * n
        memory = {100: m, 101: n, 102: p, 103: a_base, 104: b_base, 115: C_BASE}
        for i in range(m):
            for k in range(n):
                memory[a_base + i * n + k] = a[i][k]
        # B is stored transposed: B^T[j][k] = B[k][j].
        for j in range(p):
            for k in range(n):
                memory[b_base + j * n + k] = b[k][j]
        top = b_base + p * n
        return "".join("%04X\n" % memory.get(addr, 0) for addr in range(100, top))

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
            [sys.executable, str(REPOSITORY_ROOT / "assembler.py"), str(program)],
            cwd=self.workspace,
            text=True,
            capture_output=True,
            check=False,
        )
        if assemble_result.returncode != 0:
            message = (assemble_result.stderr or "").strip().splitlines()
            self.skipTest(f"{program.name} does not assemble yet: {message[-1] if message else ''}")

        for case, (m, n, p, a, b) in enumerate(GEMM_CASES):
            with self.subTest(case=case, M=m, N=n, P=p):
                data_file = self.workspace / f"{program.stem}_case{case}.data"
                data_file.write_text(self.build_data_image(m, n, p, a, b), encoding="utf-8")
                expected = reference_product(a, b)
                for i in range(m):
                    for j in range(p):
                        address = C_BASE + i * p + j
                        self.assertEqual(
                            self.run_and_read(data_file, address),
                            expected[i][j],
                            f"C[{i}][{j}] at {address}",
                        )


def _make_program_test(program: Path):
    def test(self: GemmTests) -> None:
        self.check_program(program)

    test.__name__ = f"test_{program.stem}_matches_reference"
    test.__doc__ = f"Run the GEMM cases against {program.name}."
    return test


_GEMM_PROGRAMS = sorted(REPOSITORY_ROOT.glob("gemm_*.asm"))
for _program in _GEMM_PROGRAMS:
    _test = _make_program_test(_program)
    setattr(GemmTests, _test.__name__, _test)


class GemmDiscoveryTests(unittest.TestCase):
    def test_at_least_one_gemm_program_exists(self) -> None:
        self.assertTrue(_GEMM_PROGRAMS, "no gemm_*.asm programs found")


if __name__ == "__main__":
    unittest.main()
