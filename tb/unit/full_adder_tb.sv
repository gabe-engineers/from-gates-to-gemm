`include "adder.sv"

module full_adder_tb;
  logic a;
  logic b;
  logic carry_in;
  wire out;
  wire carry_out;

  full_adder dut (
      .a(a),
      .b(b),
      .carry_in(carry_in),
      .out(out),
      .carry_out(carry_out)
  );

  task expect_sum(input tc_a, input tc_b, input tc_carry_in,
                  input expected_out, input expected_carry_out);
    begin
      a = tc_a;
      b = tc_b;
      carry_in = tc_carry_in;
      #1;
      if (out !== expected_out || carry_out !== expected_carry_out)
        $fatal(1, "full adder %b + %b + %b: got {%b, %b}, expected {%b, %b}",
               tc_a, tc_b, tc_carry_in, carry_out, out, expected_carry_out, expected_out);
    end
  endtask

  initial begin
    expect_sum(1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    expect_sum(1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
    expect_sum(1'b0, 1'b1, 1'b0, 1'b1, 1'b0);
    expect_sum(1'b0, 1'b1, 1'b1, 1'b0, 1'b1);
    expect_sum(1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
    expect_sum(1'b1, 1'b0, 1'b1, 1'b0, 1'b1);
    expect_sum(1'b1, 1'b1, 1'b0, 1'b0, 1'b1);
    expect_sum(1'b1, 1'b1, 1'b1, 1'b1, 1'b1);

    $display("full_adder_tb passed");
    $finish;
  end
endmodule
