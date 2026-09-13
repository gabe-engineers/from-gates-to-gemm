# Specs

Supports 9 bits for addressing memory. Word addressable only (not byte addressable), word size is 16 bits.
 
Scalar register file: 8 16-bit registers (`r1` through `r8`).

Vector register file: 8 vector registers (`v1` through `v8`), each with 8 lanes of 16-bit values.

## Simulation

Install [Icarus Verilog](https://steveicarus.github.io/iverilog/) and
[just](https://just.systems/), then run:

```sh
just test cpu_tb  # Run one testbench.
just test-assembler  # Run assembler unit and CPU-integration tests.
just test-all     # Run every testbench.
just clean        # Remove generated build artifacts.
```

Simulation executables are written to `build/sim/`, which is ignored by Git.

## Project Layout

- `rtl/include/` — shared ISA, ALU, and FSM definitions.
- `rtl/lib/` — reusable primitives such as gates, adders, and registers.
- `rtl/cpu/` — CPU, datapath, ALU, decoder, control, and register-file RTL.
- `rtl/memory/` — RAM RTL.
- `rtl/top/` — chip-level integration RTL.
- `tb/unit/` — focused module testbenches.
- `tb/integration/` — datapath and CPU integration testbenches.
- `build/sim/` — generated simulation artifacts; ignored by Git.

## Execution Timing

The CPU uses a multi-cycle design with a combined fetch/decode phase rather than a separate
decode state:

1. **FETCH/DECODE** — The program counter addresses instruction memory. On the rising clock
   edge, the fetched instruction is captured in the instruction register (IR), and its fields are
   decoded combinationally.
2. **EXECUTE** — The stable decoded controls drive the datapath. Register-file writeback occurs
   on the following rising edge.
3. **MEMORY** — Scalar `LOAD` and `STORE` use one additional memory phase. `VLOAD` and
   `VSTORE` use eight consecutive memory phases, one per vector lane, before returning to fetch.
   `VADD`, `VSUB`, `VMUL`, and `VDOT` execute in the normal execute phase.

Capturing the IR and writing the register file on separate edges avoids a write dependency: a
register file must not act on an instruction that is being written into the IR on that same edge.

# Instruction Set Architecture

- LDI rd immediate
- LOAD rd ra
- STORE rs ra
- VLOAD vd ra
- VSTORE vs ra
- VADD va vb vd
- VSUB va vb vd
- VMUL va vb vd
- VDOT va vb rd
- ADD rd r1 r2
- SUB rd r1 r2
- SHL rd r1 r2
- SHR rd r1 r2
- MUL rd r1 r2
- AND rd r1 r2
- OR rd r1 r2
- XOR rd r1 r2
- CMP r1 r2
- MOV rd r1
- JMP addr
- JE addr
- HALT_OR_VECTOR

`CMP` stores whether its two operands are equal in a control-unit flag. `JE` writes its target to
the program counter only when that flag is set; `JMP` always writes its target.


## Instruction Format

Every instruction is 16-bits wide. The first 4 bits are always the Opcode, the rest of the bits are interpreted based on the Opcode and can be of 5 different types.

### Register-Indirect Memory Operations

`LOAD rd ra` and `STORE rs ra` use a scalar register as the memory address. `rd` is the
load destination, `rs` is the value to store, and `ra` is the address register. `VLOAD vd ra`
and `VSTORE vs ra` use the same opcodes with the vector flag set; `vd`/`vs` select one of eight
vector registers (`v1` through `v8`) while `ra` remains a scalar address register.

Each vector register has eight 16-bit lanes. A vector transfer uses eight consecutive,
word-addressed locations: lane 0 uses `ra[8:0]`, lane 1 uses `ra[8:0] + 1`, and so on through
lane 7. Addresses wrap modulo 512. Bit 5 is the vector flag; bits 4:0 remain reserved and the
assembler emits them as zero.


| Bits           | 15:12  | 11:9                                      | 8:6                     | 5           | 4:0      |
| -------------- | ------ | ----------------------------------------- | ----------------------- | ----------- | -------- |
| Interpretation | Opcode | Scalar/vector load destination or store value | Scalar address register | Vector flag | Reserved |


### HALT-or-Vector Operations

Opcode `1111` uses its remaining twelve bits as a vector-operation format. Sub-opcode `000`
is `HALT_OR_VECTOR`; the vector instructions use `001` for `VADD`, `010` for `VSUB`, `011`
for `VMUL`, and `100` for `VDOT`. The remaining sub-opcodes are reserved and halt the processor.
`VADD`, `VSUB`, and `VMUL` are lane-wise: for every lane `i` from 0 through 7,
`vd[i] = va[i] op vb[i]`. `VDOT va vb rd` multiplies corresponding lanes, sums the eight
products, and writes the low 16 bits of the sum to scalar register `rd`. Assembly operands are
written in field order: `VADD va vb vd` and `VDOT va vb rd`.

| Bits           | 15:12 | 11:9       | 8:6              | 5:3              | 2:0             |
| -------------- | ----- | ---------- | ---------------- | ---------------- | --------------- |
| Interpretation | Opcode | Sub-opcode | Vector operand A | Vector operand B | Result register (vector for VADD/VSUB/VMUL; scalar for VDOT) |


### 3 Register Operations

Instructions like ADD, SUB, SHL, SHR, MUL, AND, OR and XOR us this instruction format.


| Bits           | 15:12  | 11:9     | 8:6            | 5:3 | 2:0 |
| -------------- | ------ | -------- | -------------- | ---- | ----|
| Interpretation | Opcode | Destination Register | Operand register 1 | Operand register 2 | Unused |


### 2 Register Operations

Instructions like CMP and MOV use two registers as input.

| Bits           | 15:12  | 11:9     | 8:6            | 5: 0 |
| -------------- | ------ | -------- | -------------- | ---- |
| Interpretation | Opcode | Operand register 1 | Operand register 2 | Unused |


### 1 Memory Address

Instructions like JMP and JE use only 1 memory address as input.

| Bits           | 15:12  | 11:0 |
| -------------- | ------ | -------- |
| Interpretation | Opcode | Memory Address |

### 1 Register and 1 immediate

LDI uses the 1 register and 1 immediate format.


| Bits           | 15:12  | 11:9                 | 8:0       |
| -------------- | ------ | -------------------- | --------- |
| Interpretation | Opcode | Destination register | Immediate |
