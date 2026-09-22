`include "alu.sv"

module subtracter_tb;
  logic [15:0] a;
  logic [15:0] b;
  wire [15:0] out;

  subtracter_16bit dut (
      .a(a),
      .b(b),
      .out(out)
  );

  task expect_difference(input [15:0] tc_a, input [15:0] tc_b, input [15:0] expected_out);
    begin
      a = tc_a;
      b = tc_b;
      #1;
      if (out !== expected_out)
        $fatal(1, "subtracter %h - %h: got %h, expected %h", tc_a, tc_b, out, expected_out);
    end
  endtask

  initial begin
    expect_difference(16'h0000, 16'h0000, 16'h0000);
    expect_difference(16'h000A, 16'h0003, 16'h0007);
    expect_difference(16'h0000, 16'h0001, 16'hFFFF);
    expect_difference(16'hFFFF, 16'h0001, 16'hFFFE);
    expect_difference(16'h8000, 16'hFFFF, 16'h8001);
    expect_difference(16'h5555, 16'hAAAA, 16'hAAAB);

    $display("subtracter_tb passed");
    $finish;
  end
endmodule
