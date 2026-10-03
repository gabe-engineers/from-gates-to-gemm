#!/usr/bin/env python3
"""Check Basys 3 GEMM results and report the on-FPGA cycle count."""

from __future__ import annotations

import argparse
import os
import re
import select
import sys
import termios
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.gemm_image import read_hex_words  # noqa: E402


def expected_words(data_path: Path) -> list[int]:
    data = read_hex_words(data_path)
    m, n, p, a_base, b_base = data[:5]
    expected = []
    for i in range(m):
        for j in range(p):
            expected.append(
                sum(
                    data[a_base - 100 + i * n + k]
                    * data[b_base - 100 + j * n + k]
                    for k in range(n)
                )
                & 0xFFFF
            )
    return expected


def configure_uart(fd: int) -> None:
    attributes = termios.tcgetattr(fd)
    attributes[0] = 0
    attributes[1] = 0
    attributes[2] = termios.CLOCAL | termios.CREAD | termios.CS8
    attributes[3] = 0
    attributes[4] = termios.B115200
    attributes[5] = termios.B115200
    attributes[6][termios.VMIN] = 0
    attributes[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attributes)
    termios.tcflush(fd, termios.TCIFLUSH)


def read_report(port: Path, count: int, timeout: float) -> tuple[list[int], int]:
    fd = os.open(port, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        configure_uart(fd)
        observed: dict[int, int] = {}
        cycle_count: int | None = None
        line_buffer = b""
        deadline = time.monotonic() + timeout
        word_pattern = re.compile(rb"@([0-9A-F]{2})=([0-9A-F]{4})")
        cycles_pattern = re.compile(rb"#CYCLES=([0-9A-F]{8})")
        while (len(observed) < count or cycle_count is None) and time.monotonic() < deadline:
            readable, _, _ = select.select([fd], [], [], max(0, deadline - time.monotonic()))
            if not readable:
                continue
            chunk = os.read(fd, 4096)
            for byte in chunk:
                if byte == 10:
                    match = word_pattern.fullmatch(line_buffer)
                    if match:
                        index = int(match.group(1), 16)
                        if index < count:
                            observed[index] = int(match.group(2), 16)
                    match = cycles_pattern.fullmatch(line_buffer)
                    if match:
                        cycle_count = int(match.group(1), 16)
                    line_buffer = b""
                elif len(line_buffer) < 64:
                    line_buffer += bytes([byte])
                else:
                    line_buffer = b""
        missing = [index for index in range(count) if index not in observed]
        if missing:
            raise RuntimeError(f"timed out waiting for result indices {missing} on {port}")
        if cycle_count is None:
            raise RuntimeError(f"timed out waiting for cycle count on {port}")
        return [observed[index] for index in range(count)], cycle_count
    finally:
        os.close(fd)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=Path, default=Path("/dev/ttyUSB1"))
    parser.add_argument("--data", type=Path, default=ROOT / "programs/gemm/input.data")
    parser.add_argument("--timeout", type=float, default=20)
    args = parser.parse_args()
    expected = expected_words(args.data)
    if len(expected) != 16:
        parser.error("the Basys 3 wrapper streams exactly 16 output words")
    actual, cycles = read_report(args.port, len(expected), args.timeout)
    if actual != expected:
        for index, (received, wanted) in enumerate(zip(actual, expected)):
            if received != wanted:
                print(f"C[{index}]: got 0x{received:04X}, expected 0x{wanted:04X}")
        return 1
    print(f"PASS: all 16 GEMM result words match on {args.port}; "
          f"{cycles} cycles at 25 MHz ({cycles / 25_000:.3f} ms)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
