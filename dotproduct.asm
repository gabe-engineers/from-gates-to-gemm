LDI r1 0 # loop index
LDI r2 64 # loop bound
LDI r3 50 # memory offset
LDI r4 1 # increment
CMP r1 r2 # loop condition
JE 10
STORE r3 r1
ADD r1 r4 r1
ADD r3 r4 r3
JMP 4
LDI r1 0 # loop index for second vector
LDI r2 64 # loop bound
LDI r3 114 # memory offset
CMP r1 r2
JE 19
STORE r3 r1
ADD r1 r4 r1
ADD r3 r4 r3
JMP 13
LDI r1 50 # V1 offset
LDI r2 114 # V2 offset
LDI r3 114 # Memory boundary to stop multiplying
LDI r4 1 # increment
LDI r8 0 # dot product result
CMP r1 r3
JE 33
LOAD r5 r1
LOAD r6 r2
MUL r7 r5 r6
ADD r8 r8 r7
ADD r1 r4 r1 # Increment offsets
ADD r2 r4 r2
JMP 24
LDI r1 250
STORE r1 r8
HALT





# Multiply every element of the vectors and start reducing the sum into a another memory location
