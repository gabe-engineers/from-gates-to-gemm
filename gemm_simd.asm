# Matrix multiplication of matrix A size (M x N) and matrix B size (N x P) using CPU SIMD instructions
#
# B is stored transposed (B^T, P x N row-major), so C[i][j] = dot(A row i, B^T row j)
# and both dot operands are contiguous, which VLD/VDOT require.

# Memory Layout:
# 0 - 99: instructions
# 100: M
# 101: N
# 102: P
# 103: Matrix_1 (A) base, M x N row-major
# 104: Matrix_2 (B^T) base, P x N row-major
# 105: function argument i
# 106: function argument j
# 107: function argument output pointer
# 114: return address
# 115: output (C) base pointer; C occupies M*P words from there

# Register Layout Core Program:
# r1: M (outer loop bound)
# r2: P (inner loop bound)
# r5: row index i
# r6: col index j
# r8: output pointer
# r3, r4, r7: address scratch and the increment
# The dot-product function clobbers every register, so i, j and the output
# pointer live in memory (105-107) across the call and are reloaded after it.

# Store return address in memory
LDI r1 23
LDI r2 114
STORE r2 r1

# Load M, P and the output pointer
LDI r1 100
LOAD r1 r1
LDI r2 102
LOAD r2 r2
LDI r8 115
LOAD r8 r8

# Outer loop over rows i
LDI r5 0
CMP r1 r5 # while (i != M)
JZ 40
LDI r6 0 # j = 0
CMP r2 r6 # while (j != P)
JZ 37

# Dump i, j and the output pointer as the function arguments
LDI r3 105
LDI r4 106
LDI r7 107
STORE r3 r5
STORE r4 r6
STORE r7 r8

# Call the dot-product function, which returns to address 23
LDI r1 41
JR r1

# Reload state, then advance j and the output pointer
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
JMP 13

# Inner loop finished: advance i and re-enter the outer loop
LDI r7 1
ADD r5 r5 r7
JMP 10

HALT

# Dot Product Function
# Computes C[i][j] = sum_k A[i*N + k] * B^T[j*N + k], stores it to the output
# pointer saved at mem[107], then returns to the address saved at mem[114].
# It consumes 8 elements at a time with VLD/VDOT while at least 8 remain, then
# finishes the remainder with a scalar tail.
# Register Layout:
# r1: N, then the lane size (8)
# r2: A pointer (A base + i*N)
# r3: B^T pointer (B^T base + j*N)
# r4: scratch (i*N, then A pointer + 8 / the A element)
# r5: scratch (j*N, then the VDOT result / the B element)
# r6: output pointer, then the return address
# r7: loop bound (A base + i*N + N)
# r8: dot product result

# Load the arguments
LDI r1 101
LOAD r1 r1
LDI r2 103
LOAD r2 r2
LDI r3 104
LOAD r3 r3
LDI r4 105
LOAD r4 r4
LDI r5 106
LOAD r5 r5
LDI r6 107
LOAD r6 r6

# A pointer = A + i*N, B^T pointer = B^T + j*N, bound = A + i*N + N
MUL r4 r4 r1
ADD r2 r2 r4
MUL r5 r5 r1
ADD r3 r3 r5
ADD r7 r2 r1
LDI r1 8 # lane size
LDI r8 0

# SIMD loop: process 8 elements while at least 8 remain
ADD r4 r2 r1 # A pointer + 8
CMP r7 r4
JLT 70 # fewer than 8 remain -> scalar tail
VLD v1 r2
VLD v2 r3
VDOT r5 v1 v2
ADD r8 r8 r5
ADD r2 r2 r1
ADD r3 r3 r1
JMP 60

# Scalar tail: one element at a time
CMP r2 r7
JZ 80
LOAD r4 r2
LOAD r5 r3
MUL r4 r4 r5
ADD r8 r8 r4
LDI r4 1
ADD r2 r2 r4
ADD r3 r3 r4
JMP 70

# Store the result to the output pointer and return
STORE r6 r8
LDI r6 114
LOAD r6 r6
JR r6
