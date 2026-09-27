![From Gates to GEMM — Understanding the path from logic gates to matrix multiplication](docs/banner.png)

# From Gates to GEMM

From Gates to GEMM builds a small 16-bit computer in SystemVerilog, from logic gates and arithmetic circuits to a scalar CPU, an 8-lane SIMD unit, and a simple SIMT GPU. Basic gates and structural arithmetic primitives are explicit building blocks; the higher-level CPU, vector, GPU, and memory modules are synthesizable SystemVerilog. Assembly programs explore how dot products and matrix multiplication map onto each execution model. The goal is to demystify the path from basic digital logic to the parallel computation underlying modern neural networks, with hardware and programs small enough to follow end to end.

## Execution models at a glance

| Model | Execution | Constraint shown here |
| --- | --- | --- |
| Scalar | One 16-bit scalar instruction and ALU path. | Loops handle one element at a time. |
| SIMD | One CPU vector instruction operates on eight 16-bit lanes; `VLD` and `VST` transfer one lane per memory cycle. | Vector chunks use a scalar tail when needed. |
| SIMT | One instruction stream is broadcast to an eight-lane warp; each lane has its own scalar registers and `TID`. | Control flow must stay uniform; divergent comparisons halt the warp. |

## Verified workloads

`just test-all` assembles and runs the checked-in scalar, SIMD, and SIMT
programs through the chip-level testbench.

| Workload | What is checked |
| --- | --- |
| Dot product | Each implementation's result matches a Python reference. |
| GEMM | Every output entry matches a Python reference for six `(M, N, P)` cases: `(3, 4, 2)`, `(4, 4, 4)`, `(2, 5, 3)`, `(2, 9, 2)`, `(2, 16, 2)`, and `(1, 8, 2)`. The cases cover SIMD tails and 16-bit wraparound. |

Expected values use 16-bit modular arithmetic. The [GEMM reference tests](tests/programs/test_gemm.py)
define the cases and check every output entry.

## Chip architecture

![Chip architecture](docs/chip-architecture.svg)

## Simulation

Install Python 3.10+, Icarus Verilog, Yosys, and `just`, then run:

```sh
just test-all                              # Verify RTL, dot products, and scalar/SIMD/SIMT GEMM.
just test-gemm                             # Reference-check scalar, SIMD, and SIMT GEMM.
just run-program path/to/program.asm       # Assemble and run an arbitrary program.
just synth-check                           # Check RTL-only code and synthesize the chip top level.
just clean                                 # Remove generated build artifacts.
```

Simulation output is written beneath `build/sim/`.

## Instruction set at a glance

Programs use eight scalar registers (`r1`–`r8`). SIMD adds eight vector
registers (`v1`–`v8`), each with eight 16-bit lanes.

| Area | Instructions | Purpose |
| --- | --- | --- |
| Scalar compute | `LDI`, `LUI`, `MOV`, `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SHL`, `SHR`, `MUL` | Build values and perform scalar computation. |
| Memory and control | `LOAD`, `STORE`, `CMP`, `JMP`, `JZ`, `JLT`, `JR`, `HALT` | Access word-addressed RAM and implement loops. |
| SIMD | `VLD`, `VST`, `VADD`, `VSUB`, `VMUL`, `VDOT` | Operate on eight lanes and reduce a vector dot product. |
| SIMT GPU | `TID`, `GLAUNCH`, `GWAIT` | Identify a warp lane, launch the GPU kernel, and wait for it. |

## Scope and limitations

- The CPU and GPU share a 1,024-word RAM; programs must keep every access within
  that installed range.
- Scalar arithmetic, multiplication, and `VDOT` retain their low 16 bits.
- The GPU is one eight-lane lockstep warp. Divergent control flow and per-lane
  predication are not supported.
- Workload evidence comes from RTL simulation. `just synth-check` performs a
  generic synthesis check, not an FPGA build, target-specific timing result, or
  hardware execution.
