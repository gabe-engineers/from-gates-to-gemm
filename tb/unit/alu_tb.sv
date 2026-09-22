`include "alu.sv"

module alu_16bit_tb;
  logic  [ 3:0] op;
  logic  [15:0] a;
  logic  [15:0] b;
  wire [15:0] out;
  alu_16bit dut (
    op,
    a,
    b,
    out
  );

  task test_case(input [3:0] tc_op, input [15:0] tc_a, input [15:0] tc_b,
                 input [15:0] expected_out);
    begin
      op = tc_op;
      a = tc_a;
      b = tc_b;
      #1;
      if (out !== expected_out) begin
        $fatal(1, "ALU op=%h, a=%h, b=%h: got %h, expected %h", tc_op, tc_a, tc_b, out,
               expected_out);
      end
    end
  endtask


  initial begin
    // MOV
    test_case(`ALU_OP_MOV, 16'hBEEF, 16'h1234, 16'hBEEF);

    // ADD
    test_case(`ALU_OP_ADD, 16'd5, 16'd7, 16'd12);
    test_case(`ALU_OP_ADD, 16'd65535, 16'd1, 16'd0);

    // SUB
    test_case(`ALU_OP_SUB, 16'd10, 16'd3, 16'd7);
    test_case(`ALU_OP_SUB, 16'd3, 16'd10, 16'd65529);
    test_case(`ALU_OP_SUB, 16'd100, 16'd100, 16'd0);

    // Basic boundaries
    test_case(`ALU_OP_SUB, 16'd0, 16'd0, 16'd0);
    test_case(`ALU_OP_SUB, 16'd65535, 16'd0, 16'd65535);
    test_case(`ALU_OP_SUB, 16'd0, 16'd65535, 16'd1);

    // Underflow / wraparound
    test_case(`ALU_OP_SUB, 16'd0, 16'd1, 16'd65535);
    test_case(`ALU_OP_SUB, 16'd1, 16'd2, 16'd65535);
    test_case(`ALU_OP_SUB, 16'd10, 16'd20, 16'd65526);
    test_case(`ALU_OP_SUB, 16'd100, 16'd200, 16'd65436);

    // Near the 16-bit boundary
    test_case(`ALU_OP_SUB, 16'd65535, 16'd1, 16'd65534);
    test_case(`ALU_OP_SUB, 16'd65535, 16'd65534, 16'd1);
    test_case(`ALU_OP_SUB, 16'd65534, 16'd65535, 16'd65535);

    // Interesting bit patterns
    test_case(`ALU_OP_SUB, 16'hAAAA, 16'h5555, 16'h5555);
    test_case(`ALU_OP_SUB, 16'h5555, 16'hAAAA, 16'hAAAB);
    test_case(`ALU_OP_SUB, 16'h8000, 16'h0001, 16'h7FFF);
    test_case(`ALU_OP_SUB, 16'h7FFF, 16'hFFFF, 16'h8000);

    // Same-value cancellation
    test_case(`ALU_OP_SUB, 16'hFFFF, 16'hFFFF, 16'h0000);
    test_case(`ALU_OP_SUB, 16'h8000, 16'h8000, 16'h0000);
    test_case(`ALU_OP_SUB, 16'h0001, 16'h0001, 16'h0000);

    // AND
    test_case(`ALU_OP_AND, 16'b1010101010101010, 16'b1100110011001100, 16'b1000100010001000);
    test_case(`ALU_OP_AND, 16'hFFFF, 16'h0F0F, 16'h0F0F);

    // OR
    test_case(`ALU_OP_OR, 16'b1010101010101010, 16'b1100110011001100, 16'b1110111011101110);
    test_case(`ALU_OP_OR, 16'h0000, 16'h5555, 16'h5555);

    // XOR
    test_case(`ALU_OP_XOR, 16'b1010101010101010, 16'b1100110011001100, 16'b0110011001100110);
    test_case(`ALU_OP_XOR, 16'hFFFF, 16'hFFFF, 16'h0000);

    // MUL retains the low 16 bits.
    test_case(`ALU_OP_MUL, 16'd12, 16'd11, 16'd132);
    test_case(`ALU_OP_MUL, 16'hFFFF, 16'd2, 16'hFFFE);

    // SHL
    test_case(`ALU_OP_SHL, 16'b0000000000000001, 16'd0, 16'b0000000000000001);
    test_case(`ALU_OP_SHL, 16'b1000000000000001, 16'd1, 16'b0000000000000010);
    test_case(`ALU_OP_SHL, 16'h0001, 16'd16, 16'h0000);

    // SHR
    test_case(`ALU_OP_SHR, 16'b1000000000000000, 16'd1, 16'b0100000000000000);
    test_case(`ALU_OP_SHR, 16'b0000000000000011, 16'd1, 16'b0000000000000001);
    test_case(`ALU_OP_SHR, 16'h8000, 16'd16, 16'h0000);

    $display("alu_16bit_tb passed");
    $finish;

  end

endmodule
