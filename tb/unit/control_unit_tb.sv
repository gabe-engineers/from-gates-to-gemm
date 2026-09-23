`include "control_unit.sv"
`include "tb_regs.svh"

module control_unit_tb;
  logic clk;
  logic reset;
  logic [15:0] memory [0:15];
  wire [15:0] mem_read_data;
  logic [15:0] datapath_read_data_a;
  logic [15:0] datapath_read_data_b;
  gpu_types::gpu_state_t gpu_state;
  wire cpu_types_pkg::control_unit_out_t out;

  control_unit dut (
      .clk(clk),
      .reset(reset),
      .mem_read_data(mem_read_data),
      .datapath_read_data_a(datapath_read_data_a),
      .datapath_read_data_b(datapath_read_data_b),
      .gpu_state(gpu_state),
      .out(out)
  );

  assign mem_read_data = memory[out.mem_addr];

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
    datapath_read_data_a = 16'hCAFE;
    datapath_read_data_b = 16'h0042;
    gpu_state = gpu_types::GPU_STATE_IDLE;
    for (int index = 0; index < 16; index++) memory[index] = 16'b0;
    memory[0] = {`OP_LDI, `REG_1, 8'd42};
    // Internal store layout is source B (address), then source A (value).
    memory[1] = {`OP_STORE, `REG_2, `REG_3, 5'd0};
    memory[2] = {`OP_HALT, 11'd0};
    tick;

    reset = 1'b0;

    // FETCH/DECODE -> EXECUTE: LDI control signals are visible.
    tick;
    if (!out.datapath_write_enable || out.datapath_dst_reg !== `REG_1 ||
        out.datapath_immediate !== 16'd42)
      $fatal(1, "control unit did not issue LDI writeback controls");

    // Completing LDI advances the fetch address to the STORE instruction.
    tick;
    if (out.mem_addr !== 16'd1)
      $fatal(1, "control unit did not advance PC after LDI");

    // STORE enters MEMORY without scalar register writeback.
    tick;
    if (out.datapath_write_enable || out.mem_write_enable ||
        out.datapath_src_reg_a !== `REG_3 || out.datapath_src_reg_b !== `REG_2)
      $fatal(1, "control unit decoded STORE controls incorrectly");
    tick;
    if (!out.mem_write_enable || out.mem_addr !== 16'h0042)
      $fatal(1, "control unit did not issue STORE memory controls");

    // The next instruction is HALT and remains halted thereafter.
    tick;
    if (out.mem_addr !== 16'd2)
      $fatal(1, "control unit did not return to the next fetch address");
    tick;
    if (out.halted)
      $fatal(1, "HALT asserted before its EXECUTE phase completed");
    tick;
    if (!out.halted)
      $fatal(1, "control unit did not hold HALT state");

    $display("control_unit_tb passed");
    $finish;
  end
endmodule
