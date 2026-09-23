`include "register_file.sv"
`include "alu.sv"
`include "warp_lane.sv"

module warp_lane_tb;
  logic clk;
  logic reset;
  logic [2:0] lane_id;
  gpu_types::warp_request_t warp_request;
  logic [15:0] mem_read_data;
  wire gpu_types::warp_lane_response_t response;

  warp_lane dut (
      .clk(clk),
      .reset(reset),
      .lane_id(lane_id),
      .warp_request(warp_request),
      .mem_read_data(mem_read_data),
      .response(response)
  );

  task tick;
    begin
      clk = 1'b0;
      #5;
      clk = 1'b1;
      #5;
    end
  endtask

  task expect_response(input [15:0] expected_response);
    begin
      #1;
      if (response.value !== expected_response)
        $fatal(1, "warp lane response: got %h, expected %h", response.value,
               expected_response);
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    lane_id = 3'd5;
    warp_request = '0;
    mem_read_data = 16'd0;
    tick;
    reset = 1'b0;

    // Immediate write to r2.
    warp_request.dst_reg = 3'd1;
    warp_request.write_enable = 1'b1;
    warp_request.writeback_source = control_helpers_pkg::WB_IMMEDIATE;
    warp_request.immediate = 16'h1234;
    tick;

    // Read r2 through MOV and write its value to r3.
    warp_request.dst_reg = 3'd2;
    warp_request.src_reg_a = 3'd1;
    warp_request.writeback_source = control_helpers_pkg::WB_ALU;
    warp_request.alu_op = `ALU_OP_MOV;
    expect_response(16'h1234);
    tick;

    // Add r2 and r3 into r4.
    warp_request.dst_reg = 3'd3;
    warp_request.src_reg_a = 3'd1;
    warp_request.src_reg_b = 3'd2;
    warp_request.alu_op = `ALU_OP_ADD;
    expect_response(16'h2468);
    tick;

    warp_request.src_reg_a = 3'd1;
    warp_request.src_reg_b = 3'd2;
    #1;
    if (!response.operands_equal)
      $fatal(1, "lane reported inequality for two equal registers");
    warp_request.src_reg_b = 3'd3;
    #1;
    if (response.operands_equal)
      $fatal(1, "lane reported equality for two unequal registers");

    // TID writes this lane's fixed ID into r5.
    warp_request.dst_reg = 3'd4;
    warp_request.writeback_source = control_helpers_pkg::WB_THREAD_ID;
    tick;
    warp_request.write_enable = 1'b0;
    warp_request.src_reg_a = 3'd4;
    warp_request.writeback_source = control_helpers_pkg::WB_ALU;
    warp_request.alu_op = `ALU_OP_MOV;
    expect_response(16'h0005);

    // A memory load writes the incoming word back through the lane.
    mem_read_data = 16'hBEEF;
    warp_request.writeback_source = control_helpers_pkg::WB_MEMORY;
    expect_response(16'hBEEF);
    mem_read_data = 16'd0;
    warp_request.writeback_source = control_helpers_pkg::WB_ALU;

    // Reset clears lane-local state.
    reset = 1'b1;
    tick;
    reset = 1'b0;
    expect_response(16'h0000);

    $display("warp_lane_tb passed");
    $finish;
  end
endmodule
