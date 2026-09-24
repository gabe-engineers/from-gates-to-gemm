# Dot product program for 2 vectors of size N using only scalar CPU instructions
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

# Compute dot product
ADD r1 r1 r2 # Memory boundary to stop multiplying
LDI r4 1 # increment
LDI r8 0 # dot product result
CMP r1 r2
JZ 18
LOAD r5 r2
LOAD r6 r3
MUL r7 r5 r6
ADD r8 r8 r7
ADD r2 r4 r2 # Increment offsets
ADD r3 r4 r3
JMP 9
LUI r1 1 # Build 511 = 0x01FF; it does not fit an LDI imm8
LDI r7 255
OR r1 r1 r7
STORE r1 r8
HALT





# Multiply every element of the vectors and start reducing the sum into a another memory location
