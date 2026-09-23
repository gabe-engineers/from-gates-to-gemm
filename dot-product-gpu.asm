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
GLAUNCH 21
GWAIT 49 # wait for the GPU, then resume at the reduction loop
LDI r1 50 # V1 offset
LDI r2 114 # V2 offset
LDI r3 50 # V1 base for the per-lane end (V1 + TID*8 + 8)
LDI r4 1 # increment
LDI r8 0 # dot product result
TID r5 # Computing the starting and ending offsets for each thread. Should be start: V offset + TID * 8, end: V offset + TID * 8 + 8
LDI r6 8
MUL r5 r5 r6
ADD r1 r5 r1
ADD r2 r5 r2
ADD r3 r5 r3
ADD r3 r6 r3
CMP r1 r3
JE 42
LOAD r5 r1
LOAD r6 r2
MUL r7 r5 r6
ADD r8 r8 r7
ADD r1 r4 r1 # Increment offsets
ADD r2 r4 r2
JMP 33
LDI r1 250
TID r3
LDI r4 8
MUL r3 r3 r4
ADD r1 r1 r3
STORE r1 r8
HALT # GPU halt
LDI r1 0
LDI r2 8
LDI r3 250
LDI r6 58
LUI r7 1
OR r4 r6 r7 # Loading 314 which is outside the 255 immediate range for one LDI
CMP r3 r4
JE 59
LOAD r5 r3
ADD r1 r1 r3
ADD r3 r3 r2
JMP 53
HALT


