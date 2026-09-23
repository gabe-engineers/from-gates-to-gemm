`include "register_file.sv"
`include "alu.sv"
`include "control_helpers.svh"
`include "warp_datapath.sv"

module warp_datapath_tb;
  logic clk;
  logic reset;
  gpu_types::warp_request_t warp_request;
  wire [7:0][15:0] lane_responses;
  wire gpu_types::warp_lane_status_t lane_status;
  wire [7:0][15:0] lane_mem_address;
  wire [7:0][15:0] lane_mem_write_data;
  wire gpu_types::gpu_mem_response_t mem_response;

  warp_datapath dut (
      .clk                (clk),
      .reset              (reset),
      .warp_request       (warp_request),
      .mem_response       (mem_response),
      .lane_responses     (lane_responses),
      .lane_status        (lane_status),
      .lane_mem_address   (lane_mem_address),
      .lane_mem_write_data(lane_mem_write_data)
  );

  task tick;
    begin
      clk = 1'b0;
      #5;
      clk = 1'b1;
      #5;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    warp_request = '0;
    tick;
    reset = 1'b0;

    // TID writes each lane's fixed, zero-extended ID into r3.
    warp_request.dst_reg = 3'd3;
    warp_request.write_enable = 1'b1;
    warp_request.writeback_source = control_helpers_pkg::WB_THREAD_ID;
    tick;

    // Read r3 back through MOV, proving the selected TID value was written.
    warp_request.write_enable = 1'b0;
    warp_request.src_reg_a = 3'd3;
    warp_request.alu_op = `ALU_OP_MOV;
    warp_request.writeback_source = control_helpers_pkg::WB_ALU;
    #1;

    for (int lane = 0; lane < 8; lane++) begin
      if (lane_responses[lane] !== lane)
        $fatal(1, "lane %0d: TID produced %0d", lane, lane_responses[lane]);
    end

    warp_request.write_enable = 1'b1;
    warp_request.writeback_source = control_helpers_pkg::WB_IMMEDIATE;
    warp_request.dst_reg = 3'd4;
    warp_request.immediate = 16'hFFFF;
    tick;
    warp_request.dst_reg = 3'd5;
    warp_request.immediate = 16'h0000;
    tick;
    warp_request.write_enable = 1'b0;
    warp_request.writeback_source = control_helpers_pkg::WB_ALU;

    warp_request.src_reg_a = 3'd3;
    warp_request.src_reg_b = 3'd3;
    #1;
    if (!lane_status.operands_equal || lane_status.diverged)
      $fatal(1, "identical operands did not produce a uniform equal result");

    warp_request.src_reg_b = 3'd4;
    #1;
    if (lane_status.operands_equal || lane_status.diverged)
      $fatal(1, "all-unequal lanes were not reported as uniform");

    warp_request.src_reg_b = 3'd5;
    #1;
    if (!lane_status.diverged || lane_status.operands_equal)
      $fatal(1, "mixed lane equality was not reported as divergence");

    for (int lane = 0; lane < 8; lane++) begin
      if (lane_mem_address[lane] !== 16'd0 || lane_mem_write_data[lane] !== lane)
        $fatal(1, "lane %0d: memory operands were not projected", lane);
    end

    $display("warp_datapath_tb passed");
    $finish;
  end
endmodule
