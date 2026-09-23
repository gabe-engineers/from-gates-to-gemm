`ifndef TB_REGS_SVH
`define TB_REGS_SVH

// Named register-field encodings for testbenches. The ISA encodes assembly
// r1/v1 as zero through r8/v8 as seven, so these names keep instruction words
// readable instead of raw 3'dN literals.

`define REG_1 3'd0
`define REG_2 3'd1
`define REG_3 3'd2
`define REG_4 3'd3
`define REG_5 3'd4
`define REG_6 3'd5
`define REG_7 3'd6
`define REG_8 3'd7

// Vector registers use the same three-bit field encodings.
`define VREG_1 3'd0
`define VREG_2 3'd1
`define VREG_3 3'd2
`define VREG_4 3'd3
`define VREG_5 3'd4
`define VREG_6 3'd5
`define VREG_7 3'd6
`define VREG_8 3'd7

`endif
