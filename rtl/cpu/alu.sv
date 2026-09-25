`ifndef ALU_V
`define ALU_V

`include "adder.sv"
`include "alu_ops.svh"

module alu_16bit (
    input        [ 3:0] operation,
    input        [15:0] operand_a,
    input        [15:0] operand_b,
    output logic [15:0] result,
    output logic        zero_flag,
    output logic        less_than_flag
);
  wire [15:0] add_out;
  wire [15:0] sub_out;
  wire [15:0] and_out;
  wire [15:0] or_out;
  wire [15:0] xor_out;
  wire [15:0] shl_out;
  wire [15:0] shr_out;

  adder_16bit add (
      operand_a,
      operand_b,
      add_out
  );

  subtracter_16bit sub (
      operand_a,
      operand_b,
      sub_out
  );

  always @(*) begin
    case (operation)
      `ALU_OP_MOV: result = operand_a;
      `ALU_OP_ADD: result = add_out;
      `ALU_OP_SUB, `ALU_OP_CMP: result = sub_out;
      `ALU_OP_AND: result = operand_a & operand_b;
      `ALU_OP_OR: result = operand_a | operand_b;
      `ALU_OP_XOR: result = operand_a ^ operand_b;
      `ALU_OP_SHL: result = operand_a << operand_b;
      `ALU_OP_SHR: result = operand_a >> operand_b;
      `ALU_OP_MUL: result = operand_a * operand_b;
      default:     result = 16'b0;
    endcase

    // Comparison flags. CMP aliases the subtracter, so zero_flag is equality and
    // less_than_flag is a signed compare taken from the difference: when the
    // signs differ the negative operand is smaller, otherwise the subtraction
    // cannot overflow and its MSB is the sign of a - b.
    zero_flag      = result == 16'b0;
    less_than_flag = (operand_a[15] ^ operand_b[15]) ? operand_a[15] : result[15];
  end

endmodule

module subtracter_16bit (
    input  [15:0] a,
    input  [15:0] b,
    output [15:0] out
);
  wire [15:0] b_ones_compliment = ~b;
  wire [15:0] b_twos_compliment;
  adder_16bit twos_compliment_adder (
      b_ones_compliment,
      16'd1,
      b_twos_compliment
  );
  adder_16bit adder (
      a,
      b_twos_compliment,
      out
  );

endmodule

`endif
