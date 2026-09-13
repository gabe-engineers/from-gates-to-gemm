LDI r1 0 # Load first vector
LDI r2 99
LDI r3 100
LDI r4 1
CMP r1 r2
JE 11
STORE r1 r3
ADD r1 r4 r1
ADD r3 r4 r3
JMP 5
LDI r1 0 # Load second vector
LDI r2 99
LDI r3 200
CMP r1 r2
JE 20
STORE r1 r3
ADD r1 r4 r1
ADD r3 r4 r3
JMP 14 
LDI r1 100 # V1 offset
LDI r2 200 # V2 offset
LDI r3 200 # Memory boundary to stop multiplying
LDI r4 1 # increment
LDI r8 0 # dot product result
CMP r1 r3
JE 34
LOAD r5 r1
LOAD r6 r2
MUL r5 r6 r7
ADD r7 r8
ADD r1 r4 r1 # Increment offsets
ADD r2 r4 r2
JMP 25
HALT_OR_VECTOR





# Multiply every element of the vectors and start reducing the sum into a another memory location
