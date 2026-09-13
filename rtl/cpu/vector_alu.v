`include "isa.vh"
`include "alu.v"

module vector_alu_16bit (
    input  [ 2:0] operation,
    input  [127:0] a,
    input  [127:0] b,
    output [127:0] out,
    output [15:0] dot_product
);
  wire [3:0] scalar_alu_operation =
      operation == `HALT_OR_VECTOR_SUBOP_VADD ? `OP_ADD :
      operation == `HALT_OR_VECTOR_SUBOP_VSUB ? `OP_SUB : `OP_MUL;

  wire [15:0] dot_sum_01;
  wire [15:0] dot_sum_23;
  wire [15:0] dot_sum_45;
  wire [15:0] dot_sum_67;
  wire [15:0] dot_sum_0123;
  wire [15:0] dot_sum_4567;

  genvar lane;
  generate
    for (lane = 0; lane < 8; lane = lane + 1) begin : vector_lanes
      alu_16bit lane_alu (
          .op (scalar_alu_operation),
          .a  (a[lane * 16 +: 16]),
          .b  (b[lane * 16 +: 16]),
          .out(out[lane * 16 +: 16])
      );
    end
  endgenerate

  // VDOT sums the eight lane products. The adder tree deliberately retains
  // only 16 bits at each stage, matching the scalar register width.
  adder_16bit dot_adder_01 (.a(out[ 15:  0]), .b(out[ 31: 16]), .out(dot_sum_01));
  adder_16bit dot_adder_23 (.a(out[ 47: 32]), .b(out[ 63: 48]), .out(dot_sum_23));
  adder_16bit dot_adder_45 (.a(out[ 79: 64]), .b(out[ 95: 80]), .out(dot_sum_45));
  adder_16bit dot_adder_67 (.a(out[111: 96]), .b(out[127:112]), .out(dot_sum_67));
  adder_16bit dot_adder_0123 (.a(dot_sum_01), .b(dot_sum_23), .out(dot_sum_0123));
  adder_16bit dot_adder_4567 (.a(dot_sum_45), .b(dot_sum_67), .out(dot_sum_4567));
  adder_16bit dot_adder_final (.a(dot_sum_0123), .b(dot_sum_4567), .out(dot_product));
endmodule
