LDI r1 0 # loop index
LDI r2 50 # loop bound
LDI r3 50 # memory offset
LDI r4 1 # increment
CMP r1 r2 # loop condition
JE 10
STORE r3 r1
ADD r1 r4 r1
ADD r3 r4 r3
JMP 4
LDI r1 0 # loop index
LDI r2 50 # loop bound
LDI r3 100 # memory offset
LDI r4 1 # increment
CMP r1 r2 # loop condition
JE 20
STORE r3 r1
ADD r1 r4 r1
ADD r3 r4 r3
JMP 14
LDI r1 50 # V1 offset
LDI r2 100 # V2 offset
LDI r3 106 # Memory boundary to stop operations
LDI r4 8 # increment
LDI r6 0 # dot product result
CMP r1 r3
JE 34
VLD v1 r1
VLD v2 r2
VDOT r5 v1 v2
ADD r6 r5 r6
ADD r1 r4 r1 # Increment offsets
ADD r2 r4 r2
JMP 25
HALT
