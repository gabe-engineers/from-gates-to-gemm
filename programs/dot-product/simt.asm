# Dot product for two vectors of size N using the SIMT unit, with the CPU
# reducing the per-lane partials.
#
# Assumptions:
# - Instruction memory 0-99; data memory from 100
# - mem[100] = N, mem[101] = V1 base, mem[102] = V2 base
# - N and every element index are non-negative and below 2^15, so the sign bit
#   of (index - bound) is set exactly when index < bound
# - Reads up to V1 base + 64 must still land in RAM (they are masked, not used)
# - Each of the 8 lanes handles 8 contiguous elements. Out-of-range elements are
#   multiplied by a 0/1 mask instead of branched over, so every lane runs the
#   same number of iterations and the warp never diverges
# - Per-lane partials at mem[104 + TID]; result at mem[511]

# CPU: launch the kernel, then reduce the per-lane partials
GLAUNCH 2
GWAIT 36

# GPU kernel
LDI r1 101
LOAD r1 r1        # V1 base
LDI r2 102
LOAD r2 r2        # V2 base
LDI r5 100
LOAD r5 r5        # N
ADD r5 r5 r1      # bound = V1 base + N
TID r6
LDI r7 8
MUL r6 r6 r7      # TID * 8
ADD r1 r6 r1      # V1 ptr = V1 base + TID*8
ADD r2 r6 r2      # V2 ptr = V2 base + TID*8
ADD r3 r1 r7      # V1 end = ptr + 8
LDI r4 1          # increment
LDI r7 15         # shift amount for the mask
LDI r8 0          # per-lane partial
CMP r1 r3
JZ 31             # 8 elements done -> store the partial
SUB r6 r1 r5      # index - bound
SHR r6 r6 r7      # mask = (index < bound) ? 1 : 0
LOAD r7 r1        # V1[index]
MUL r6 r6 r7      # mask * V1[index]
LOAD r7 r2        # V2[index]
MUL r6 r6 r7      # mask * V1[index] * V2[index]
ADD r8 r8 r6      # accumulate
LDI r7 15         # restore the shift amount
ADD r1 r1 r4
ADD r2 r2 r4
JMP 18

LDI r1 104
TID r6
ADD r1 r1 r6
STORE r1 r8
HALT              # GPU halt

# CPU: reduce the 8 partials into mem[511]
LDI r1 104
LDI r2 8
ADD r2 r1 r2      # bound = 104 + 8
LDI r3 1
LDI r4 0
CMP r1 r2
JZ 47
LOAD r5 r1
ADD r4 r4 r5
ADD r1 r1 r3
JMP 41
LUI r1 1          # Build 511 = 0x01FF
LDI r5 255
OR r1 r1 r5
STORE r1 r4
HALT
