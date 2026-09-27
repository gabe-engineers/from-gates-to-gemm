# Dot product for two vectors of size N using only scalar CPU instructions.
#
# Memory layout:
# - Locations 0-99 are reserved for code
# - mem[100] = N, mem[101] = V1 base, mem[102] = V2 base
# - V1 occupies mem[V1 base .. V1 base + N - 1]
# - V2 occupies mem[V2 base .. V2 base + N - 1]
# - Result is written to mem[511]
#
# Register layout:
# - r1 = N during setup, then V1 end pointer, then the result address
# - r2 = current V1 pointer
# - r3 = current V2 pointer
# - r4 = increment (1)
# - r5 = current V1 element
# - r6 = current V2 element
# - r7 = element product, then the result-address low byte
# - r8 = accumulated dot product
#
# V1 and V2 contain N contiguous 16-bit elements.

# Load parameters
LDI r1 100 
LOAD r1 r1 # r1 = N
LDI r2 101
LOAD r2 r2 # r2 = V1
LDI r3 102
LOAD r3 r3 # r3 = V2

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
