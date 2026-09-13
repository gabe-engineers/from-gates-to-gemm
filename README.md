# From Gates to GEMM

This project implements a multi-cycle 16-bit scalar and SIMD processor in Verilog.

## Machine organization

- Instructions and words are 16 bits.
- Scalar register file: eight 16-bit registers, named `r1` through `r8`.
- Vector register file: eight registers, named `v1` through `v8`, with eight
  16-bit lanes per register.
- Memory is word-addressed.
- The PC and register-held memory addresses are 16 bits.
- The supplied RAM contains 512 words. Access outside the installed RAM range is
  undefined behavior; architectural address width and physical RAM capacity are
  intentionally separate.

## Simulation

Install Icarus Verilog and `just`, then run:

```sh
just test cpu_tb       # Run one testbench.
just test-assembler   # Run assembler and assembler/CPU tests.
just test-all         # Run every testbench.
just clean
```

Simulation output is written beneath `build/sim/`.

### Run an arbitrary assembly program

The generic `program_tb` loads an assembled hex program, runs it until `HALT`,
and prints the final scalar registers. It does not provide program-specific
input data or assertions.

```sh
just run-program path/to/program.asm
```

That command assembles the source into `program.hex` in the repository root,
then runs `program_tb`. To run an already-assembled image, use:

```sh
just test program_tb
```

`program_tb` accepts optional VVP plusargs when invoking the simulator
directly: `+PROGRAM=path/to/program.hex`, `+TIMEOUT=10000`, and
`+VCD=build/sim/program.vcd`.

## Execution timing

The CPU uses a multi-cycle design:

1. **FETCH/DECODE** captures the memory word in the instruction register.
2. **EXECUTE** performs scalar/vector ALU work and register writeback.
3. **MEMORY** performs scalar transfers in one cycle. `VLD` and `VST` use eight
   memory cycles, one per vector lane.

`HALT` stops instruction execution without clearing registers. Reset clears the
PC, scalar registers, vector registers, and equality flag and resumes fetching.

## Instruction set

| Opcode | Assembly | Behavior |
| --- | --- | --- |
| `0x00` | `LDI rd imm8` | Zero-extend an unsigned 8-bit immediate |
| `0x01` | `MOV rd rs` | Copy a scalar register |
| `0x02` | `ADD rd ra rb` | Add |
| `0x03` | `SUB rd ra rb` | Subtract |
| `0x04` | `AND rd ra rb` | Bitwise AND |
| `0x05` | `OR rd ra rb` | Bitwise OR |
| `0x06` | `XOR rd ra rb` | Bitwise XOR |
| `0x07` | `SHL rd ra rb` | Logical left shift |
| `0x08` | `SHR rd ra rb` | Logical right shift |
| `0x09` | `MUL rd ra rb` | Multiply |
| `0x0A` | `LOAD rd raddr` | Load one word |
| `0x0B` | `STORE raddr rs` | Store one word; address operand comes first |
| `0x0C` | `CMP ra rb` | Set the equality flag |
| `0x0D` | `JMP addr11` | Absolute jump to a zero-extended 11-bit address |
| `0x0E` | `JE addr11` | Jump when the equality flag is set (`JZ` is an alias) |
| `0x0F` | `HALT` | Stop without clearing registers |
| `0x10` | `VLD vd raddr` | Load eight consecutive words |
| `0x11` | `VST raddr vs` | Store eight consecutive words; address first |
| `0x12` | `VADD vd va vb` | Lane-wise addition |
| `0x13` | `VSUB vd va vb` | Lane-wise subtraction |
| `0x14` | `VMUL vd va vb` | Lane-wise multiplication |
| `0x15` | `VDOT rd va vb` | Dot product into a scalar register |
| `0x16–0x1F` | Reserved/deferred | Unsupported; no assembler mnemonic |

`GLAUNCH`, `GWAIT`, `TID`, and `LUI` are intentionally not implemented yet.
Unsupported opcodes stop the current CPU implementation without side effects.

Arithmetic, multiplication, and `VDOT` retain the low 16 bits. Logical shifts
by 16 or more produce zero. Only `CMP` changes the equality flag.

Because `LUI` is deferred, immediate constants above 255 must currently be
computed with scalar instructions or loaded from memory.

## Encoding

All reserved bits must be zero in assembler output.

| Format | Bits, most significant first |
| --- | --- |
| Three registers | `opcode[5] A[3] B[3] C[3] reserved[2]` |
| Two registers | `opcode[5] A[3] B[3] reserved[5]` |
| One register | `opcode[5] A[3] reserved[8]` |
| Immediate | `opcode[5] rd[3] immediate[8]` |
| Jump | `opcode[5] address[11]` |
| No operands | `opcode[5] reserved[11]` |

Registers use zero-based three-bit encodings internally: assembly register `r1`
or `v1` is encoded as zero, and `r8` or `v8` is encoded as seven. Operands occupy
fields in assembly order, including address-first stores.
