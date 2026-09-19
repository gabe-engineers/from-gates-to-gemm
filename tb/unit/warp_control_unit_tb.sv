`include "register.sv"
`include "decoder.sv"
`include "control_fsm.sv"
`include "warp_control_unit.sv"

module warp_control_unit_tb;
  logic clk;
  logic reset;
  logic [15:0] mem_read_data;
  wire gpu_types::lane_request_t lane_request;

  warp_control_unit dut (
      .clk          (clk),
      .reset        (reset),
      .mem_read_data(mem_read_data),
      .out          (lane_request)
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
    mem_read_data = {`OP_TID, 3'd6, 8'd0};
    tick;

    reset = 1'b0;
    tick;
    #1;

    if (lane_request.dst_reg !== 3'd6)
      $fatal(1, "TID destination register was not decoded");
    if (lane_request.writeback_source !== control_helpers_pkg::WB_THREAD_ID)
      $fatal(1, "TID did not select the thread-ID writeback source");
    if (!lane_request.write_enable)
      $fatal(1, "TID did not enable scalar-register writeback");

    $display("warp_control_unit_tb passed");
    $finish;
  end
endmodule
