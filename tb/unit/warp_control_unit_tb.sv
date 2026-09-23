`include "register.sv"
`include "control_fsm.sv"
`include "warp_control_unit.sv"
`include "tb_regs.svh"

module warp_control_unit_tb;
  logic clk;
  logic reset;
  logic [15:0] start_address;
  logic enable;
  logic [15:0] mem_read_data;
  gpu_types::warp_lane_status_t lane_status;
  wire gpu_types::warp_control_unit_out_t control_out;

  warp_control_unit dut (
      .clk          (clk),
      .reset        (reset),
      .start_address(start_address),
      .enable       (enable),
      .lane_status  (lane_status),
      .mem_read_data(mem_read_data),
      .out          (control_out)
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
    lane_status.operands_equal = 1'b1;
    lane_status.diverged = 1'b0;
    mem_read_data = {`OP_TID, `REG_7, 8'd0};
    tick;

    reset = 1'b0;
    tick;
    #1;

    if (control_out.instruction_address !== 16'd23)
      $fatal(1, "warp did not start from the supplied instruction address");

    if (control_out.warp_request.dst_reg !== `REG_7)
      $fatal(1, "TID destination register was not decoded");
    if (control_out.warp_request.writeback_source !== control_helpers_pkg::WB_THREAD_ID)
      $fatal(1, "TID did not select the thread-ID writeback source");
    if (!control_out.warp_request.write_enable)
      $fatal(1, "TID did not enable scalar-register writeback");

    // CPU vector opcodes are invalid in the scalar/SIMT warp ISA. They must
    // halt the warp rather than becoming a silent no-op.
    reset = 1'b1;
    mem_read_data = {`OP_VADD, `VREG_1, `VREG_2, `VREG_3, 2'd0};
    tick;
    reset = 1'b0;
    tick;
    #1;
    if (control_out.warp_request.write_enable)
      $fatal(1, "invalid warp instruction enabled a lane register write");
    tick;
    #1;
    if (!control_out.halted)
      $fatal(1, "invalid warp instruction did not halt the warp");

    reset = 1'b1;
    start_address = 16'd23;
    mem_read_data = {`OP_CMP, `REG_2, `REG_3, 5'd0};
    lane_status.operands_equal = 1'b1;
    lane_status.diverged = 1'b0;
    tick;
    reset = 1'b0;
    tick;
    #1;
    if (dut.cmp_equal_flag !== 1'b0)
      $fatal(1, "equality flag changed before CMP executed");
    lane_status.operands_equal = 1'b1;
    tick;
    #1;
    if (dut.cmp_equal_flag !== 1'b1)
      $fatal(1, "uniform CMP did not set the warp equality flag");

    mem_read_data = {`OP_JE, 11'd100};
    tick;
    tick;
    #1;
    if (control_out.instruction_address !== 16'd100)
      $fatal(1, "JE did not redirect the warp PC");

    reset = 1'b1;
    mem_read_data = {`OP_CMP, `REG_2, `REG_3, 5'd0};
    lane_status.diverged = 1'b1;
    tick;
    reset = 1'b0;
    tick;
    #1;
    lane_status.diverged = 1'b1;
    tick;
    #1;
    if (!control_out.halted)
      $fatal(1, "divergent CMP did not halt the warp");

    $display("warp_control_unit_tb passed");
    $finish;
  end
endmodule
