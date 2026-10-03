sim_dir := "build/sim"
asm_dir := "build/asm"
rtl_filelist := "rtl/filelists/chip.f"
include_dirs := "-Irtl/include -Itb/include"
vivado_bin := env_var_or_default("VIVADO", "vivado")

default: test-all

# Run one testbench, for example: just test cpu_tb
# Extra arguments are passed to vvp, e.g. just test program_tb +DATA=vec.data
test target *args:
    #!/usr/bin/env sh
    set -eu
    mkdir -p {{sim_dir}}
    testbench=$(find tb/unit tb/integration -type f -name "{{target}}.sv" -print -quit)
    if [ -z "$testbench" ]; then
      printf '%s\n' "Unknown testbench: {{target}}" >&2
      exit 1
    fi
    iverilog -g2012 {{include_dirs}} -f {{rtl_filelist}} -o {{sim_dir}}/{{target}} "$testbench"
    vvp {{sim_dir}}/{{target}} {{args}}

# Assemble an arbitrary source program and run it in the generic chip harness.
# Extra arguments are passed to vvp, e.g.:
#   just run-program foo.asm +DATA=foo.data +RESULT=511
run-program source *args:
    mkdir -p {{asm_dir}}
    python3 tools/assembler.py "{{source}}" --output {{asm_dir}}/program.hex
    just test program_tb +PROGRAM={{asm_dir}}/program.hex {{args}}

# Assemble and run the checked-in scalar N-size dot-product program.
test-dotproduct:
    just run-program programs/dot-product/scalar.asm +DATA=programs/dot-product/scalar.data +RESULT=511

# Assemble and run the checked-in SIMD dot-product program.
test-dotproduct-simd:
    just run-program programs/dot-product/simd.asm +DATA=programs/dot-product/simd.data +RESULT=511
# Assemble and run the checked-in SIMT GPU dot-product program.
test-dotproduct-simt:
    just run-program programs/dot-product/simt.asm +DATA=programs/dot-product/simt.data +RESULT=511

# Assemble and reference-check all checked-in scalar, SIMD, and SIMT GEMM programs.
test-gemm:
    python3 -m unittest tests.programs.test_gemm -v

# Assemble scalar, SIMD, and SIMT GEMM into complete 1024-word FPGA RAM images.
fpga-images data="programs/gemm/input.data":
    python3 tools/gemm_image.py --data "{{data}}"

# Reference-check all three GEMM programs in Vivado's FPGA memory simulation.
fpga-sim: fpga-images
    sh scripts/fpga/test_xsim.sh

# Build a Basys 3 bitstream with the selected GEMM program and input.
fpga-build variant data="programs/gemm/input.data": (fpga-images data)
    GEMM_VARIANT="{{variant}}" "{{vivado_bin}}" -mode batch -source scripts/fpga/build_basys3.tcl -log build/fpga/basys3_{{variant}}_vivado.log -nojournal

# Program the connected Basys 3 with an already built variant.
fpga-program variant:
    GEMM_VARIANT="{{variant}}" "{{vivado_bin}}" -mode batch -source scripts/fpga/program_basys3.tcl -log build/fpga/basys3_{{variant}}_program.log -nojournal

# Check all 16 UART output words and report the on-FPGA cycle count.
fpga-check *args:
    python3 scripts/fpga/check_gemm_uart.py {{args}}

# Build, program, verify, and compare all three variants with an M=P=4, N-wide input.
fpga-bench n="16" port="/dev/ttyUSB1":
    python3 scripts/fpga/benchmark_gemm.py --n "{{n}}" --port "{{port}}"

# Sweep N in XSim with the same FPGA memory path and check every output word.
fpga-sweep-sim *args:
    python3 scripts/fpga/sweep_gemm_xsim.py {{args}}

# Assemble and run the checked-in SIMD GEMM program (C is at 116..131).
test-gemm-simd:
    just run-program programs/gemm/simd.asm +DATA=programs/gemm/input.data +RESULT=116

# Assemble and run the checked-in SIMT GEMM program (C is at 116..131).
test-gemm-simt:
    just run-program programs/gemm/simt.asm +DATA=programs/gemm/input.data +RESULT=116

test-all:
    just test adder_tb
    just test full_adder_tb
    just test alu_tb
    just test subtracter_tb
    just test-assembler
    just test control_fsm_tb
    just test cpu_tb
    just test chip_tb
    just test datapath_tb
    just test decoder_tb
    just test gates_tb
    just test gpu_tb
    just test program_counter_tb
    just test memory_tb
    just test register_file_tb
    just test vector_alu_tb
    just test vector_register_file_tb
    just test vector_register_tb
    just test control_unit_tb
    just test warp_control_unit_tb
    just test warp_decoder_tb
    just test warp_datapath_tb
    just test warp_lane_tb
    just test warp_memory_tb
    just test warp_tb
    just test register_tb

test-assembler:
    python3 -m unittest discover -s tests -t . -p 'test_*.py' -v

clean:
    rm -rf build
