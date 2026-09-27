![From Gates to GEMM — Understanding the path from logic gates to matrix multiplication](docs/banner.png)

# From Gates to GEMM

From Gates to GEMM builds a small 16-bit computer in SystemVerilog, from logic gates and arithmetic circuits to a scalar CPU, an 8-lane SIMD unit, and a simple SIMT GPU. Assembly programs explore how dot products and matrix multiplication map onto each execution model. The goal is to demystify the path from basic digital logic to the parallel computation underlying modern neural networks, with hardware and programs small enough to follow end to end.

## Execution models at a glance

| Model | Execution | Constraint shown here |
| --- | --- | --- |
| Scalar | One 16-bit scalar instruction and ALU path. | Loops handle one element at a time. |
| SIMD | One CPU vector instruction operates on eight 16-bit lanes; `VLD` and `VST` transfer one lane per memory cycle. | Vector chunks use a scalar tail when needed. |
| SIMT | One instruction stream is broadcast to an eight-lane warp; each lane has its own scalar registers and `TID`. | Control flow must stay uniform; divergent comparisons halt the warp. |

## Chip architecture

![Chip architecture](docs/chip-architecture.svg)

## Simulation

Install Python 3.10+, Icarus Verilog, Yosys, and `just`, then run:

```sh
just test-all                              # Verify RTL, dot products, and scalar/SIMD/SIMT GEMM.
just test-gemm                             # Assemble and run the checked-in scalar GEMM sample.
just run-program path/to/program.asm       # Assemble and run an arbitrary program.
just synth-check                           # Check RTL-only code and synthesize the chip top level.
just clean                                 # Remove generated build artifacts.
```

Simulation output is written beneath `build/sim/`.

## Memory and execution boundary

RAM is one shared array of 1024 words. Reads are combinational: the addressed
word appears in the same cycle, so there is no read latency and nothing to wait
on. Writes commit on the clock edge. There is no ready/valid handshake, so a
client must present an address on the exact cycle it needs the data, and assert
`write_enable` only on the cycle it intends to write. When multiple writers act
on the same edge, priority is program load, then CPU, then GPU; among GPU lanes
the highest-numbered lane wins. A losing write is dropped with no signal.

Reset is synchronous for the CPU, GPU, and scalar/vector registers, but it does
not clear RAM. Words are zero only at power-up (simulation time zero or FPGA
configuration), so a reload leaves previously used locations holding the old
program's data. `GLAUNCH` does not merely start the warp: the warp is reset
first, reloading the PC with the launch address and clearing every lane's
registers.
`GWAIT` stalls only the CPU until the warp halts; otherwise the CPU and GPU run
concurrently against the same RAM.

## Instruction set at a glance

Programs use eight scalar registers (`r1`–`r8`). SIMD adds eight vector
registers (`v1`–`v8`), each with eight 16-bit lanes. Arithmetic is 16-bit;
`MUL` and `VDOT` retain their low 16 bits.

| Area | Instructions | Purpose |
| --- | --- | --- |
| Scalar compute | `LDI`, `LUI`, `MOV`, `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SHL`, `SHR`, `MUL` | Build values and perform scalar computation. |
| Memory and control | `LOAD`, `STORE`, `CMP`, `JMP`, `JZ`, `JLT`, `JR`, `HALT` | Access word-addressed RAM and implement loops. |
| SIMD | `VLD`, `VST`, `VADD`, `VSUB`, `VMUL`, `VDOT` | Operate on eight lanes and reduce a vector dot product. |
| SIMT GPU | `TID`, `GLAUNCH`, `GWAIT` | Identify a warp lane, launch the GPU kernel, and wait for it. |

Unsupported opcodes stop the current CPU implementation with no register,
memory, or GPU side effects; the PC has already advanced past the instruction.

The GPU reports registered `IDLE`/`RUNNING` state to the CPU. `GLAUNCH` is a
one-cycle command accepted only in `IDLE`; its zero-extended `addr11` operand
becomes the warp's first instruction address. `GWAIT` is CPU-local and sends
no command to the GPU; after the GPU reports `IDLE` it resumes the CPU at its
zero-extended `addr11` operand. This makes the wait skip over an inline GPU
kernel, so a program can lay out the CPU and warp code in one image.

Warp code uses a scalar/SIMT subset: `LDI`, `LUI`, `MOV`, scalar arithmetic,
`LOAD`, `STORE`, `CMP`, `JMP`, `JZ`, `JLT`, `TID`, and `HALT` (`JR` is CPU-only).
Each supported
instruction is broadcast across the warp's lanes. `CMP` reconciles every lane's
equality and less-than results into warp flags; if the lanes disagree on either
result, the warp halts, because divergent warps are not supported. CPU SIMD and
GPU-coordination opcodes are invalid in a warp and halt it.

Divergence being unsupported means there is no per-lane predication: a lane that
should be inactive cannot be branched around. Variable-length work such as a
partial SIMT tail is therefore handled with an arithmetic 0/1 mask, and masked
lanes still execute their loads, so every address a warp reaches during a masked
iteration must lie inside installed RAM. This idiom relies on the signed
comparison flags and assumes nonnegative indices below 2^15.

Arithmetic, multiplication, and `VDOT` retain the low 16 bits. Logical shifts
by 16 or more produce zero. Only `CMP` changes the comparison flags, which are
signed.

Use `LUI` together with `LDI` and a logical operation such as `OR` to construct
16-bit constants from two 8-bit immediate values.
