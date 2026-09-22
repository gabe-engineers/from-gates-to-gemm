`include "register.sv"
`include "control_fsm.sv"
`include "warp_control_unit.sv"

module warp_control_unit_tb;
  logic clk;
  logic reset;
  logic [15:0] start_address;
  logic enable;
  logic [15:0] mem_read_data;
  wire halted;
  wire [15:0] instruction_address;
  wire gpu_types::lane_request_t lane_request;

  warp_control_unit dut (
      .clk          (clk),
      .reset        (reset),
      .start_address(start_address),
      .enable       (enable),
      .mem_read_data(mem_read_data),
      .halted       (halted),
      .instruction_address(instruction_address),
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
    start_address = 16'd23;
    enable = 1'b1;
    mem_read_data = {`OP_TID, 3'd6, 8'd0};
    tick;

    reset = 1'b0;
    tick;
    #1;

    if (instruction_address !== 16'd23)
      $fatal(1, "warp did not start from the supplied instruction address");

    if (lane_request.dst_reg !== 3'd6)
      $fatal(1, "TID destination register was not decoded");
    if (lane_request.writeback_source !== control_helpers_pkg::WB_THREAD_ID)
      $fatal(1, "TID did not select the thread-ID writeback source");
    if (!lane_request.write_enable)
      $fatal(1, "TID did not enable scalar-register writeback");

    // CPU vector opcodes are invalid in the scalar/SIMT warp ISA. They must
    // halt the warp rather than becoming a silent no-op.
    reset = 1'b1;
    mem_read_data = {`OP_VADD, 3'd0, 3'd1, 3'd2, 2'd0};
    tick;
    reset = 1'b0;
    tick;
    #1;
    if (lane_request.write_enable)
      $fatal(1, "invalid warp instruction enabled a lane register write");
    tick;
    #1;
    if (!halted)
      $fatal(1, "invalid warp instruction did not halt the warp");

    $display("warp_control_unit_tb passed");
    $finish;
  end
endmodule
