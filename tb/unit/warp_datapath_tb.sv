`include "register_file.sv"
`include "alu.sv"
`include "warp_datapath.sv"

module warp_datapath_tb;
  logic clk;
  logic reset;
  gpu_types::lane_request_t lane_request;
  wire [7:0][15:0] lane_responses;

  warp_datapath dut (
      .clk           (clk),
      .reset         (reset),
      .lane_request  (lane_request),
      .lane_responses(lane_responses)
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
    lane_request = '0;
    tick;
    reset = 1'b0;

    // TID writes each lane's fixed, zero-extended ID into r3.
    lane_request.dst_reg = 3'd3;
    lane_request.write_enable = 1'b1;
    lane_request.writeback_source = control_helpers_pkg::WB_THREAD_ID;
    tick;

    // Read r3 back through MOV, proving the selected TID value was written.
    lane_request.write_enable = 1'b0;
    lane_request.src_reg_a = 3'd3;
    lane_request.alu_op = `ALU_OP_MOV;
    lane_request.writeback_source = control_helpers_pkg::WB_ALU;
    #1;

    for (int lane = 0; lane < 8; lane++) begin
      if (lane_responses[lane] !== lane)
        $fatal(1, "lane %0d: TID produced %0d", lane, lane_responses[lane]);
    end

    $display("warp_datapath_tb passed");
    $finish;
  end
endmodule
