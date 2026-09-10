# Specs

Supports 9 bits for addressing memory. Word addressable only (not byte addressable), word size is 16 bits.
 
Number of registers: 8 16-bit registers

## Simulation

Install [Icarus Verilog](https://steveicarus.github.io/iverilog/) and
[just](https://just.systems/), then run:

```sh
just test cpu_tb  # Run one testbench.
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
3. **MEMORY** — `LOAD` and `STORE` use an additional memory phase before returning to fetch.

Capturing the IR and writing the register file on separate edges avoids a write dependency: a
register file must not act on an instruction that is being written into the IR on that same edge.

# Instruction Set Architecture

- LDI rd immediate
- LOAD rd addr
- STORE rs addr
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
- HALT

`CMP` stores whether its two operands are equal in a control-unit flag. `JE` writes its target to
the program counter only when that flag is set; `JMP` always writes its target.


## Instruction Format

Every instruction is 16-bits wide. The first 4 bits are always the Opcode, the rest of the bits are interpreted based on the Opcode and can be of 5 different types.

### 1 Register and 1 Memory Address

LOAD and STORE instructions have this type. The format is `OP r addr` standing for the register destination/start and the memory address for the operation.


| Bits           | 15:12  | 11:9     | 8:0            |
| -------------- | ------ | -------- | -------------- |
| Interpretation | Opcode | Register | Memory address |


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
