#!/usr/bin/env python3
"""Reject common simulation-only constructs in design SystemVerilog.

This is intentionally a small, conservative policy check.  It complements the
actual Yosys synthesis pass run by synth_check.sh; it does not attempt to parse
or synthesize SystemVerilog itself.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Pattern, Tuple


@dataclass(frozen=True)
class Rule:
    name: str
    pattern: Pattern[str]
    guidance: str


RULES: Tuple[Rule, ...] = (
    Rule(
        "unpacked queue declaration",
        re.compile(r"\[\s*\$(?:\s*:\s*[^\]\r\n]+)?\s*\]"),
        "Use a fixed-size unpacked array with parameterized bounds instead.",
    ),
    Rule(
        "dynamic array declaration",
        re.compile(r"\[\s*\]"),
        "Use a fixed-size unpacked array with parameterized bounds instead.",
    ),
    Rule(
        "queue or dynamic-array operation",
        re.compile(
            r"\.\s*(?:push_(?:front|back)|pop_(?:front|back)|insert|delete)\s*\("
        ),
        "Use fixed storage and explicit control logic instead.",
    ),
    Rule(
        "unpacked-array locator or reduction method",
        re.compile(
            r"\.\s*(?:find(?:_(?:first|last)(?:_index)?|_index)?|min|max|"
            r"unique(?:_index)?|and|or|xor|sum|product)\s*\(\s*\)\s*with\b"
        ),
        "Use a fixed-bound loop that produces fixed-width result signals instead.",
    ),
    Rule(
        "testbench-only object or randomization construct",
        re.compile(
            r"\b(?:class|mailbox|semaphore|covergroup|program|clocking|"
            r"rand|randc|randomize|constraint)\b"
        ),
        "Keep this construct in tb/; model the RTL behavior with static logic.",
    ),
    Rule(
        "simulation process control",
        re.compile(r"\b(?:fork|join(?:_any|_none)?|wait(?:_order)?|disable\s+fork)\b"),
        "Use clocked or combinational RTL control logic instead.",
    ),
    Rule(
        "delay control",
        re.compile(r"(?<!`)#\s*(?!\()"),
        "Use clocked RTL; delays do not describe portable hardware.",
    ),
    Rule(
        "simulation system task",
        re.compile(
            r"\$(?:display|write|monitor|strobe|finish|stop|fatal|error|warning|"
            r"info|random|urandom(?:_range)?|dump\w*)\b"
        ),
        "Keep simulation system tasks in tb/ or guard nonfunctional diagnostics.",
    ),
)


NON_CODE = re.compile(
    r"//[^\r\n]*|/\*.*?\*/|\"(?:\\.|[^\"\\])*\"", re.DOTALL
)


def mask_non_code(source: str) -> str:
    """Preserve offsets and line numbers while removing comments and strings."""

    def replace(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group())

    return NON_CODE.sub(replace, source)


def rtl_sources(root: Path) -> Iterable[Path]:
    yield from root.glob("*.sv")
    yield from root.glob("*.svh")
    yield from (root / "rtl").rglob("*.sv")
    yield from (root / "rtl").rglob("*.svh")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    failures: List[Tuple[Path, int, Rule]] = []
    sources = sorted(set(rtl_sources(root)))

    for path in sources:
        source = path.read_text(encoding="utf-8")
        code = mask_non_code(source)
        for rule in RULES:
            for match in rule.pattern.finditer(code):
                line = code.count("\n", 0, match.start()) + 1
                failures.append((path.relative_to(root), line, rule))

    if not failures:
        print(f"RTL policy check passed ({len(sources)} source files checked).")
        return 0

    print("RTL policy check failed:", file=sys.stderr)
    for path, line, rule in failures:
        print(f"  {path}:{line}: {rule.name}. {rule.guidance}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
