# Dot product program for 2 vectors of size N using SIMD CPU instructions with a scalar tail
# Assumptions:
# - Instruction memory goes from 0-99, the rest is data memory
# - Size of vectors N is in memory location 100. The address first element of V1 and V2 are in memory locations 101 and 102 respectively
# - Both vectors have size N
# - Stores result in memory location 511

# Load parameters N, v1 and v2 into r1, r2, r3
LDI r1 100
LOAD r1 r1
LDI r2 101
LOAD r2 r2
LDI r3 102
LOAD r3 r3

# SIMD loop: consume 8 elements at a time while at least 8 remain
LDI r4 8 # number of lanes / SIMD stride
LDI r6 0 # dot product result
CMP r1 r4
JLT 18 # remaining < 8 -> scalar tail
VLD v1 r2
VLD v2 r3
VDOT r5 v1 v2
ADD r6 r5 r6
ADD r2 r4 r2 # Advance V1 pointer
ADD r3 r4 r3 # Advance V2 pointer
SUB r1 r1 r4 # remaining -= 8
JMP 8

# Scalar tail: one element at a time while any remain
LDI r4 1 # stride
LDI r7 0
CMP r1 r7
JZ 30 # remaining == 0 -> store
LOAD r5 r2
LOAD r8 r3
MUL r8 r8 r5
ADD r6 r8 r6
ADD r2 r4 r2 # Advance V1 pointer
ADD r3 r4 r3 # Advance V2 pointer
SUB r1 r1 r4 # remaining -= 1
JMP 20

# Store the result at memory location 511 (does not fit an LDI imm8)
LUI r1 1
LDI r7 255
OR r1 r1 r7
STORE r1 r6
HALT
