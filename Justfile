sim_dir := "build/sim"
include_dirs := "-Irtl/include -Irtl/lib -Irtl/cpu -Irtl/memory -Irtl/top -Itb/include"

default: test-all

# Run one testbench, for example: just test cpu_tb
# Extra arguments are passed to vvp, e.g. just test program_tb +DATA=vec.data
test target *args:
    #!/usr/bin/env sh
    set -eu
    mkdir -p {{sim_dir}}
    if [ -f tb/integration/{{target}}.sv ]; then
      testbench=tb/integration/{{target}}.sv
    elif [ -f tb/unit/{{target}}.sv ]; then
      testbench=tb/unit/{{target}}.sv
    else
      printf '%s\n' "Unknown testbench: {{target}}" >&2
      exit 1
    fi
    iverilog -g2012 {{include_dirs}} -o {{sim_dir}}/{{target}} "$testbench"
    vvp {{sim_dir}}/{{target}} {{args}}

# Assemble an arbitrary source program and run it in the generic CPU harness.
# Extra arguments are passed to vvp, e.g.:
#   just run-program foo.asm +DATA=foo.data +RESULT=511
run-program source *args:
    python3 assembler.py "{{source}}"
    just test program_tb {{args}}

# Assemble and run the checked-in scalar N-size dot-product program.
test-dotproduct:
    just run-program dot_product_scalar.asm +DATA=dot_product_scalar.data +RESULT=511

# Assemble and run the checked-in SIMD dot-product program.
test-dotproduct-simd:
    just run-program dot_product_simd.asm +DATA=dot_product_simd.data +RESULT=511
# Assemble and run the checked-in SIMT GPU dot-product program.
test-dotproduct-simt:
    just run-program dot_product_simt.asm +DATA=dot_product_simt.data +RESULT=511

# Assemble and run the checked-in scalar GEMM program (C is at 116..131).
test-gemm:
    just run-program gemm_scalar.asm +DATA=gemm_scalar.data +RESULT=116

synth-check:
    sh scripts/synth_check.sh

test-all:
    just synth-check
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
    python3 -m unittest discover -s tests -p 'test_*.py' -v

clean:
    rm -rf build
