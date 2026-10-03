#!/usr/bin/env python3
# Assemble each GEMM variant and place its instructions and shared matrix data
# into a 1024-word RAM image. Split that image across eight interleaved bank
# files (address % 8 selects the bank) so Vivado can preload the FPGA memory
# when it builds each variant's bitstream.
"""Build complete 1024-word RAM images for the three GEMM implementations."""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

if __package__:
    from .assembler import Assembler
else:
    from assembler import Assembler


ROOT = Path(__file__).resolve().parents[1]
RAM_WORDS = 1024
DATA_BASE = 100
VARIANTS = ("scalar", "simd", "simt")


def read_hex_words(path: Path) -> list[int]:
    words = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        value = line.split("#", 1)[0].strip()
        if not value:
            continue
        try:
            word = int(value, 16)
        except ValueError as exc:
            raise ValueError(f"{path}:{line_number}: invalid hexadecimal word") from exc
        if not 0 <= word <= 0xFFFF:
            raise ValueError(f"{path}:{line_number}: word exceeds 16 bits")
        words.append(word)
    return words


def validate_layout(data: list[int], program_size: int) -> dict[str, int]:
    if program_size > DATA_BASE:
        raise ValueError(f"program uses {program_size} words and overlaps data at {DATA_BASE}")
    if len(data) < 16 or DATA_BASE + len(data) > RAM_WORDS:
        raise ValueError("data image must include metadata through address 115 and fit in RAM")

    m, n, p, a_base, b_base = data[:5]
    c_base = data[15]
    if min(m, n, p) < 1:
        raise ValueError("M, N, and P must be positive")
    regions = {
        "metadata": (DATA_BASE, 116),
        "C": (c_base, c_base + m * p),
        "A": (a_base, a_base + m * n),
        "B_transposed": (b_base, b_base + p * n),
    }
    for name, (start, end) in regions.items():
        if start < 0 or end > RAM_WORDS:
            raise ValueError(f"{name} extends outside the {RAM_WORDS}-word RAM")
    for left, (left_start, left_end) in regions.items():
        for right, (right_start, right_end) in regions.items():
            if left >= right:
                continue
            if max(left_start, right_start) < min(left_end, right_end):
                raise ValueError(f"{left} and {right} overlap")
    # SIMT reads every lane in its last block, even when the product is masked.
    padded_n = ((n + 7) // 8) * 8
    if a_base + (m - 1) * n + padded_n > RAM_WORDS:
        raise ValueError("last A row's SIMT padded reads extend outside RAM")
    if b_base + (p - 1) * n + padded_n > RAM_WORDS:
        raise ValueError("last B row's SIMT padded reads extend outside RAM")
    if max(regions["A"][1], regions["B_transposed"][1]) > DATA_BASE + len(data):
        raise ValueError("data image does not contain all matrix elements")
    return {
        "M": m,
        "N": n,
        "P": p,
        "A_base": a_base,
        "B_transposed_base": b_base,
        "C_base": c_base,
        "C_words": m * p,
    }


def build_images(data_path: Path, output_dir: Path) -> None:
    data = read_hex_words(data_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    for variant in VARIANTS:
        source = ROOT / "programs" / "gemm" / f"{variant}.asm"
        with tempfile.TemporaryDirectory() as directory:
            program_path = Path(directory) / "program.hex"
            Assembler().assemble_file(str(source), program_path)
            program = read_hex_words(program_path)
        layout = validate_layout(data, len(program))
        image = [0] * RAM_WORDS
        image[: len(program)] = program
        image[DATA_BASE : DATA_BASE + len(data)] = data
        (output_dir / f"gemm_{variant}.mem").write_text(
            "".join(f"{word:04X}\n" for word in image), encoding="ascii"
        )
        for bank in range(8):
            (output_dir / f"gemm_{variant}_bank{bank}.mem").write_text(
                "".join(f"{image[address]:04X}\n" for address in range(bank, RAM_WORDS, 8)),
                encoding="ascii",
            )
        manifest = {"variant": variant, "program_words": len(program), **layout}
        (output_dir / f"gemm_{variant}.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        print(f"{variant}: {len(program)} instructions, C at {layout['C_base']}.."
              f"{layout['C_base'] + layout['C_words'] - 1}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=ROOT / "programs/gemm/input.data")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/fpga")
    args = parser.parse_args()
    build_images(args.data, args.output_dir)


if __name__ == "__main__":
    main()
