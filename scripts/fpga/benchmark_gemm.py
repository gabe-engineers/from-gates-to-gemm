#!/usr/bin/env python3
"""Build, run, verify, and compare selected GEMM programs on a Basys 3."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from scripts.fpga.check_gemm_uart import expected_words, read_report  # noqa: E402

CLOCK_HZ = 25_000_000
VARIANTS = ("scalar", "simd", "simt")


def write_input(n: int, path: Path) -> None:
    """Make identical 4 x N and N x 4 matrices for every variant."""
    if not 1 <= n <= 111:
        raise ValueError("N must be 1..111 to fit the 1024-word FPGA memory")
    a_base = 132
    b_base = a_base + 4 * n
    data = [0] * (32 + 8 * n)  # RAM addresses 100 through the end of B^T.
    data[0:5] = [4, n, 4, a_base, b_base]
    data[15] = 116  # C occupies addresses 116..131.
    for row in range(4):
        for k in range(n):
            data[a_base - 100 + row * n + k] = (row * 7 + k * 3 + 1) % 16
            data[b_base - 100 + row * n + k] = (row * 5 + k * 7 + 2) % 16
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(f"{word:04X}\n" for word in data), encoding="ascii")


def run_just(*args: str) -> None:
    subprocess.run(("just", *args), cwd=ROOT, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=16, help="inner dimension (default: 16)")
    parser.add_argument("--port", type=Path, default=Path("/dev/ttyUSB1"))
    parser.add_argument("--timeout", type=float, default=20)
    parser.add_argument("--variants", nargs="+", choices=VARIANTS, default=VARIANTS)
    args = parser.parse_args()
    if len(set(args.variants)) != len(args.variants):
        parser.error("--variants must not repeat a variant")
    data_path = ROOT / f"build/fpga/benchmark_n{args.n}.data"
    try:
        write_input(args.n, data_path)
    except ValueError as exc:
        parser.error(str(exc))
    expected = expected_words(data_path)
    measurements: dict[str, int] = {}

    for variant in args.variants:
        print(f"\n{variant}: building, programming, and checking 4x{args.n}x4 GEMM", flush=True)
        run_just("fpga-build", variant, str(data_path))
        run_just("fpga-program", variant)
        actual, cycles = read_report(args.port, len(expected), args.timeout)
        if actual != expected:
            differences = [
                f"C[{i}]: got 0x{got:04X}, expected 0x{want:04X}"
                for i, (got, want) in enumerate(zip(actual, expected)) if got != want
            ]
            raise RuntimeError(f"{variant} FPGA result mismatch: " + "; ".join(differences))
        if cycles == 0:
            raise RuntimeError(f"{variant} reported zero execution cycles")
        measurements[variant] = cycles
        print(f"{variant}: PASS, {cycles} cycles ({cycles / CLOCK_HZ * 1000:.3f} ms)", flush=True)

    baseline = "scalar" if "scalar" in measurements else args.variants[0]
    print(f"\nVerified 4x{args.n}x4 GEMM on {args.port} at 25 MHz")
    print(f"variant     cycles    time (ms)  speedup vs {baseline}  MMAC/s")
    baseline_cycles = measurements[baseline]
    macs = 16 * args.n
    for variant in args.variants:
        cycles = measurements[variant]
        print(f"{variant:<8} {cycles:>9} {cycles / CLOCK_HZ * 1000:>12.3f} "
              f"{baseline_cycles / cycles:>17.2f} {macs / cycles * CLOCK_HZ / 1e6:>8.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
