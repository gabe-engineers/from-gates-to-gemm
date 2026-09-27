# Dot product for two vectors of size N using the SIMT unit, with the CPU
# reducing the per-lane partials.
#
# Memory layout:
# - Locations 0-99 are reserved for code
# - mem[100] = N, mem[101] = V1 base, mem[102] = V2 base
# - V1 occupies mem[V1 base .. V1 base + N - 1]
# - V2 occupies mem[V2 base .. V2 base + N - 1]
# - Per-lane partials are stored at mem[104 + TID] (mem[104..111])
# - Result is written to mem[511]
#
# Register layout (the CPU and each GPU lane have independent register files):
# - CPU r1 = partial pointer, then result address
# - CPU r2 = end of the partial range; CPU r3 = reduction increment (1)
# - CPU r4 = accumulated dot product; CPU r5 = current partial, then result-address low byte
# - GPU r1 = current V1 pointer, then partial-store address
# - GPU r2 = current V2 pointer; GPU r3 = lane-local V1 end pointer
# - GPU r4 = increment (1); GPU r5 = V1 bound (V1 base + N)
# - GPU r6 = lane offset, then mask/product temporary, then TID at the partial store
# - GPU r7 = lane stride / mask shift amount / current vector element
# - GPU r8 = accumulated per-lane partial
#
# The 0/1 mask in the loop body zeroes the product of out-of-range lanes but
# does not skip the loads: each lane always executes its full eight iterations,
# so the loads still touch V1/V2 base through base + 63 (for N <= 64). Those
# addresses must stay inside installed RAM. The mask relies on the signed
# comparison flags and assumes nonnegative indices below 2^15.


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
