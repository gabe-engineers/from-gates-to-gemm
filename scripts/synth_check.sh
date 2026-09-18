#!/usr/bin/env sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

python3 scripts/rtl_policy_check.py

yosys_bin=${YOSYS:-yosys}
if ! command -v "$yosys_bin" >/dev/null 2>&1; then
  printf '%s\n' "Yosys is required for synth-check. Install it or set YOSYS to its path." >&2
  exit 127
fi

mkdir -p build/synth
"$yosys_bin" -l build/synth/chip.log -s scripts/chip_synth.ys
