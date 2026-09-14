`include "isa.vh"

module decoder (
    input      [15:0] instruction_data,
    output     [ 4:0] opcode,
    output logic [ 2:0] dst_reg,
    output logic [ 2:0] src_reg_a,
    output logic [ 2:0] src_reg_b,
    output logic [15:0] immediate,
    output logic [15:0] address
);
  assign opcode = instruction_data[15:11];

  always @(*) begin
    dst_reg   = 3'b000;
    src_reg_a = 3'b000;
    src_reg_b = 3'b000;
    immediate = 16'b0;
    address   = 16'b0;

    case (opcode)
      `OP_ADD, `OP_SUB, `OP_SHR, `OP_SHL, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR,
      `OP_VADD, `OP_VSUB, `OP_VMUL, `OP_VDOT: begin
        dst_reg   = instruction_data[10:8];
        src_reg_a = instruction_data[7:5];
        src_reg_b = instruction_data[4:2];
      end

      `OP_LOAD, `OP_VLD: begin
        dst_reg   = instruction_data[10:8];
        src_reg_b = instruction_data[7:5];
      end

      // Stores are address-first in assembly. The internal B read port remains
      // the address port, and A remains the scalar/vector value selector.
      `OP_STORE, `OP_VST: begin
        src_reg_b = instruction_data[10:8];
        src_reg_a = instruction_data[7:5];
      end

      `OP_CMP: begin
        src_reg_a = instruction_data[10:8];
        src_reg_b = instruction_data[7:5];
      end

      `OP_MOV: begin
        dst_reg   = instruction_data[10:8];
        src_reg_a = instruction_data[7:5];
      end

      `OP_LDI: begin
        dst_reg   = instruction_data[10:8];
        immediate = {8'b0, instruction_data[7:0]};
      end
      `OP_LUI: begin
        dst_reg   = instruction_data[10:8];
        immediate = {instruction_data[7:0], 8'b0};
      end

      `OP_JMP, `OP_JE: begin
        address = {5'b0, instruction_data[10:0]};
      end
    endcase
  end
endmodule
