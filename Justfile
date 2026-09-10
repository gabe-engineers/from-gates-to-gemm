sim_dir := "build/sim"
rtl_include_dirs := "-Irtl/include -Irtl/lib -Irtl/cpu -Irtl/memory -Irtl/top"

default: test-all

# Run one testbench, for example: just test cpu_tb
test target:
    #!/usr/bin/env sh
    set -eu
    mkdir -p {{sim_dir}}
    if [ -f tb/integration/{{target}}.v ]; then
      testbench=tb/integration/{{target}}.v
    elif [ -f tb/unit/{{target}}.v ]; then
      testbench=tb/unit/{{target}}.v
    else
      printf '%s\n' "Unknown testbench: {{target}}" >&2
      exit 1
    fi
    iverilog -g2012 {{rtl_include_dirs}} -o {{sim_dir}}/{{target}} "$testbench"
    vvp {{sim_dir}}/{{target}}

test-all:
    just test adder_tb
    just test alu_tb
    just test control_fsm_tb
    just test cpu_tb
    just test datapath_tb
    just test decoder_tb
    just test gates_tb
    just test program_counter_tb
    just test ram_tb
    just test register_file_tb
    just test register_tb

clean:
    rm -rf build
