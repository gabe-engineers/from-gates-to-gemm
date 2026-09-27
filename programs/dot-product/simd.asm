# Dot product for two vectors of size N using SIMD CPU instructions with a scalar tail.
#
# Memory layout:
# - Locations 0-99 are reserved for code
# - mem[100] = N, mem[101] = V1 base, mem[102] = V2 base
# - V1 occupies mem[V1 base .. V1 base + N - 1]
# - V2 occupies mem[V2 base .. V2 base + N - 1]
# - Result is written to mem[511]
#
# Register layout:
# - r1 = remaining element count, then the result address
# - r2 = current V1 pointer
# - r3 = current V2 pointer
# - r4 = SIMD stride (8), then scalar-tail stride (1)
# - r5 = SIMD partial dot product, then current scalar V1 element
# - r6 = accumulated dot product
# - r7 = scalar-tail zero sentinel, then the result-address low byte
# - r8 = current scalar V2 element, then its product with V1
# - v1 = current eight-element V1 chunk
# - v2 = current eight-element V2 chunk
#
# V1 and V2 contain N contiguous 16-bit elements.

# Load parameters
LDI r1 100
LOAD r1 r1 # r1 = N
LDI r2 101
LOAD r2 r2 # r2 = V1
LDI r3 102
LOAD r3 r3 # r3 = V2

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
