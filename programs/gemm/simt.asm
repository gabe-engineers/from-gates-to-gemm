# Matrix multiplication of A (M x N) and B (N x P) with the SIMT GPU.
#
# B is stored transposed (B^T, P x N row-major), so
# C[i][j] = sum_k A[i*N + k] * B^T[j*N + k]. The GPU gives each lane the
# indices TID, TID+8, TID+16, ... and the CPU reduces the eight partial sums.
#
# Its only conditional GPU branch compares the uniform block offset with N.
# The final partial block uses a branchless 0/1 mask, so all lanes keep
# identical control flow even when N is not divisible by eight.

# Memory Layout:
# 0 - 99: instructions
# 100: M
# 101: N
# 102: P
# 103: A base, M x N row-major
# 104: B^T base, P x N row-major
# 105: current i argument
# 106: current j argument
# 107: current C output pointer argument
# 108 - 115: one GPU partial per lane. Before the first launch, mem[115]
#             holds the C base pointer; later output pointers live in mem[107],
#             so the kernel can reuse mem[115] as partial[7].
# C must not overlap 108 - 115 (the shared test image uses C at 116).

# CPU: nested C[i][j] loop. Each iteration saves its arguments, launches the
# GPU kernel, waits at address 20, reduces partial[0..7], and stores C[i][j].
LDI r1 100
LOAD r1 r1
LDI r2 102
LOAD r2 r2
LDI r8 115
LOAD r8 r8
LDI r5 0

# outer_cmp = 7
CMP r1 r5
JZ 50
LDI r6 0

# inner_cmp = 10
CMP r2 r6
JZ 47

LDI r3 105
LDI r4 106
LDI r7 107
STORE r3 r5
STORE r4 r6
STORE r7 r8
GLAUNCH 51
GWAIT 20

# CPU reduction: sum mem[108] through mem[115].
LDI r1 108
LDI r2 116
LDI r3 1
LDI r4 0

# reduce_cmp = 24
CMP r1 r2
JZ 30
LOAD r5 r1
ADD r4 r4 r5
ADD r1 r1 r3
JMP 24

# Store the reduced result through the output pointer saved before launch.
LDI r1 107
LOAD r1 r1
STORE r1 r4

# Restore loop state, then advance j and the C pointer.
LDI r1 100
LOAD r1 r1
LDI r2 102
LOAD r2 r2
LDI r5 105
LOAD r5 r5
LDI r6 106
LOAD r6 r6
LDI r8 107
LOAD r8 r8
LDI r7 1
ADD r6 r6 r7
ADD r8 r8 r7
JMP 10

# outer_increment = 47
LDI r7 1
ADD r5 r5 r7
JMP 7

HALT

# GPU kernel, address 51. Each lane accumulates the logical index k = block +
# TID. r4 is the uniform block offset and r1=N, so this CMP/JLT pair has the
# same outcome in every lane.
# r1: N
# r2: A row base
# r3: B^T row base
# r4: block offset
# r5: lane partial sum
# r6: i/j offset during setup; then k and the B^T address/value in the loop;
#     finally, the address for this lane's partial
# r7: mask / lane id at store
# r8: mask-shift count, then the A address/value and masked product
LDI r1 101
LOAD r1 r1
LDI r2 103
LOAD r2 r2
LDI r3 104
LOAD r3 r3
LDI r6 105
LOAD r6 r6
MUL r6 r6 r1
ADD r2 r2 r6
LDI r6 106
LOAD r6 r6
MUL r6 r6 r1
ADD r3 r3 r6
LDI r4 0
LDI r5 0

# gpu_loop_cmp = 67. r4 and r1 are uniform here, so this JLT is uniform.
CMP r4 r1
JLT 70
JMP 85

# gpu_loop_body = 70
TID r6
ADD r6 r6 r4
SUB r7 r6 r1
LDI r8 15
SHR r7 r7 r8
ADD r8 r2 r6
LOAD r8 r8
MUL r8 r8 r7
ADD r6 r3 r6
LOAD r6 r6
MUL r8 r8 r6
ADD r5 r5 r8
LDI r6 8
ADD r4 r4 r6
JMP 67

# gpu_done = 85: write one distinct partial per lane, then halt the GPU.
LDI r6 108
TID r7
ADD r6 r6 r7
STORE r6 r5
HALT
