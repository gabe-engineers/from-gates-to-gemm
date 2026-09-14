`include "vector_alu.sv"

module vector_alu_tb;
  logic  [ 4:0] operation;
  logic  [127:0] a;
  logic  [127:0] b;
  wire [127:0] out;
  wire [15:0] dot_product;

  vector_alu_16bit dut (
      .operation(operation),
      .a        (a),
      .b        (b),
      .out      (out),
      .dot_product(dot_product)
  );

  task test_case(input [7:0] test_number, input [4:0] tc_operation,
                 input [127:0] expected_out);
    begin
      operation = tc_operation;
      #1;
      if (out !== expected_out)
        $fatal(1, "Test case #%d failed - operation: %b | got: %h, expected: %h",
               test_number, operation, out, expected_out);
    end
  endtask

  initial begin
    // Lane 0 is stored in bits [15:0]; lane 7 is stored in bits [127:112].
    a = 128'h0050_0046_003C_0032_0028_001E_0014_000A;
    b = 128'h0008_0007_0006_0005_0004_0003_0002_0001;

    test_case(.test_number(1), .tc_operation(`OP_VADD),
              .expected_out(128'h0058_004D_0042_0037_002C_0021_0016_000B));
    test_case(.test_number(2), .tc_operation(`OP_VSUB),
              .expected_out(128'h0048_003F_0036_002D_0024_001B_0012_0009));
    test_case(.test_number(3), .tc_operation(`OP_VMUL),
              .expected_out(128'h0280_01EA_0168_00FA_00A0_005A_0028_000A));
    test_case(.test_number(4), .tc_operation(`OP_VDOT),
              .expected_out(128'h0280_01EA_0168_00FA_00A0_005A_0028_000A));
    if (dot_product !== 16'd2040)
      $fatal(1, "VDOT produced %0d; expected 2040", dot_product);

    $finish;
  end
endmodule
