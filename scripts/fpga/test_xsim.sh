#!/usr/bin/env sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_dir"
mkdir -p build/fpga

vivado_bin=$(command -v "${VIVADO:-vivado}") || {
  printf '%s\n' 'Vivado is required; set VIVADO to its executable path.' >&2
  exit 127
}
bin_dir=$(dirname -- "$vivado_bin")

"$bin_dir/xvlog" -sv -i rtl/include -f rtl/filelists/chip.f \
  tb/integration/system/fpga_gemm_tb.sv >build/fpga/xvlog.log 2>&1

for variant in scalar simd simt; do
  snapshot="fpga_gemm_$variant"
  "$bin_dir/xelab" fpga_gemm_tb -s "$snapshot" -timescale 1ns/1ps \
    -generic_top "IMAGE_PREFIX=build/fpga/gemm_$variant" \
    >"build/fpga/xelab_$variant.log" 2>&1
  "$bin_dir/xsim" "$snapshot" -runall >"build/fpga/xsim_$variant.log" 2>&1
  if ! rg -q 'FPGA GEMM preload, scratch, and reset path PASS' "build/fpga/xsim_$variant.log"; then
    cat "build/fpga/xsim_$variant.log" >&2
    exit 1
  fi
  printf '%s\n' "$variant FPGA GEMM simulation passed"
done
