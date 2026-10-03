#!/usr/bin/env python3
"""Sweep GEMM inner dimensions in XSim and verify every output word."""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from scripts.fpga.benchmark_gemm import write_input  # noqa: E402
from scripts.fpga.check_gemm_uart import expected_words  # noqa: E402
from tools.gemm_image import build_images  # noqa: E402

VARIANTS = ("scalar", "simd", "simt")
DEFAULT_N = (7, 8, 14, 15, 16, 24, 32, 48, 64, 80, 96, 103, 104, 110, 111)


def run(command: list[str], log: Path) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    output = result.stdout + result.stderr
    log.write_text(output, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{' '.join(command)} failed; see {log}\n"
                           + "\n".join(output.splitlines()[-20:]))
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("n", nargs="*", type=int, help="specific inner dimensions")
    parser.add_argument("--max-n", type=int, help="sweep every N from 1 through this value")
    parser.add_argument("--output", type=Path, default=Path("build/fpga/sweep/cycles.csv"))
    args = parser.parse_args()
    if args.max_n is not None and args.n:
        parser.error("use either specific N values or --max-n")
    if args.max_n is not None and not 1 <= args.max_n <= 111:
        parser.error("--max-n must be 1..111")
    values = range(1, args.max_n + 1) if args.max_n is not None else (args.n or DEFAULT_N)
    if any(not 1 <= n <= 111 for n in values):
        parser.error("each N must be 1..111")

    vivado = shutil.which(os.environ.get("VIVADO", "vivado"))
    if vivado is None:
        parser.error("Vivado is required; set VIVADO to its executable path")
    bin_dir = Path(vivado).resolve().parent
    output_dir = ROOT / "build/fpga/sweep"
    output_dir.mkdir(parents=True, exist_ok=True)
    run([str(bin_dir / "xvlog"), "-sv", "-i", "rtl/include", "-f",
         "rtl/filelists/chip.f", "tb/integration/system/fpga_benchmark_tb.sv"],
        output_dir / "xvlog.log")
    for variant in VARIANTS:
        run([str(bin_dir / "xelab"), "fpga_benchmark_tb", "-s",
             f"fpga_benchmark_{variant}", "-timescale", "1ns/1ps",
             "-generic_top", f"IMAGE_PREFIX=build/fpga/sweep/gemm_{variant}"],
            output_dir / f"xelab_{variant}.log")

    rows: list[dict[str, int]] = []
    for n in values:
        data_path = output_dir / f"input_n{n}.data"
        write_input(n, data_path)
        build_images(data_path, output_dir)
        expected = expected_words(data_path)
        row = {"N": n}
        for variant in VARIANTS:
            output = run([str(bin_dir / "xsim"), f"fpga_benchmark_{variant}", "-runall"],
                         output_dir / f"xsim_n{n}_{variant}.log")
            observed = {int(index): int(value, 16) for index, value in
                        re.findall(r"BENCH_WORD=(\d+):([0-9a-fA-F]{4})", output)}
            if observed != dict(enumerate(expected)):
                raise RuntimeError(f"{variant}, N={n} result mismatch: {observed}")
            match = re.search(r"BENCH_CYCLES=(\d+)", output)
            if match is None:
                raise RuntimeError(f"missing cycle count for {variant}, N={n}")
            row[variant] = int(match.group(1))
        rows.append(row)
        print(f"N={n:3d}: scalar={row['scalar']:6d}, simd={row['simd']:6d}, "
              f"simt={row['simt']:6d}, SIMT/SIMD={row['simt'] / row['simd']:.3f}",
              flush=True)

    csv_path = args.output if args.output.is_absolute() else ROOT / args.output
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=("N", *VARIANTS), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    try:
        shown_path = csv_path.relative_to(ROOT)
    except ValueError:
        shown_path = csv_path
    print(f"Saved {shown_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
