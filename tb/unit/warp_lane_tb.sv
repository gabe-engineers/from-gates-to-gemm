`include "register_file.sv"
`include "alu.sv"
`include "warp_lane.sv"

module warp_lane_tb;
  logic clk;
  logic reset;
  logic [2:0] lane_id;
  gpu_types::lane_request_t lane_request;
  wire [15:0] out;

  warp_lane dut (
      .clk(clk),
      .reset(reset),
      .lane_id(lane_id),
      .lane_request(lane_request),
      .out(out)
  );

  task tick;
    begin
      clk = 1'b0;
      #5;
      clk = 1'b1;
      #5;
    end
  endtask

  task expect_out(input [15:0] expected_out);
    begin
      #1;
      if (out !== expected_out)
        $fatal(1, "warp lane output: got %h, expected %h", out, expected_out);
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    lane_id = 3'd5;
    lane_request = '0;
    tick;
    reset = 1'b0;

    // Immediate write to r2.
    lane_request.dst_reg = 3'd1;
    lane_request.write_enable = 1'b1;
    lane_request.writeback_source = control_helpers_pkg::WB_IMMEDIATE;
    lane_request.immediate = 16'h1234;
    tick;

    // Read r2 through MOV and write its value to r3.
    lane_request.dst_reg = 3'd2;
    lane_request.src_reg_a = 3'd1;
    lane_request.writeback_source = control_helpers_pkg::WB_ALU;
    lane_request.alu_op = `ALU_OP_MOV;
    expect_out(16'h1234);
    tick;

    // Add r2 and r3 into r4.
    lane_request.dst_reg = 3'd3;
    lane_request.src_reg_a = 3'd1;
    lane_request.src_reg_b = 3'd2;
    lane_request.alu_op = `ALU_OP_ADD;
    expect_out(16'h2468);
    tick;

    // TID writes this lane's fixed ID into r5.
    lane_request.dst_reg = 3'd4;
    lane_request.writeback_source = control_helpers_pkg::WB_THREAD_ID;
    tick;
    lane_request.write_enable = 1'b0;
    lane_request.src_reg_a = 3'd4;
    lane_request.writeback_source = control_helpers_pkg::WB_ALU;
    lane_request.alu_op = `ALU_OP_MOV;
    expect_out(16'h0005);

    // Reset clears lane-local state.
    reset = 1'b1;
    tick;
    reset = 1'b0;
    expect_out(16'h0000);

    $display("warp_lane_tb passed");
    $finish;
  end
endmodule
