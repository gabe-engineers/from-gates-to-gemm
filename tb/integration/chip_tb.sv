`include "chip.sv"
`include "tb_regs.svh"

module chip_tb;
  logic clk;
  logic reset;
  logic load_enable;
  logic [15:0] load_address;
  logic [15:0] load_data;
  wire halted;
  integer cycles;
  logic saw_cpu_wait;
  logic saw_gpu_running;

  chip dut (
      .clk(clk),
      .reset(reset),
      .load_enable(load_enable),
      .load_address(load_address),
      .load_data(load_data),
      .halted(halted)
  );

  task tick;
    begin
      clk = 1'b0;
      #5;
      clk = 1'b1;
      #5;
    end
  endtask

  task load_word(input [15:0] address, input [15:0] data);
    begin
      load_enable  = 1'b1;
      load_address = address;
      load_data    = data;
      tick;
      load_enable = 1'b0;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    load_enable = 1'b0;
    load_address = 16'b0;
    load_data = 16'b0;
    cycles = 0;
    saw_cpu_wait = 1'b0;
    saw_gpu_running = 1'b0;

    // Preload the end-to-end program through the RAM load port while reset is
    // held. It proves GLAUNCH's address reaches the warp instruction fetch path
    // through chip.
    load_word(16'd0, {`OP_LDI, `REG_1, 8'd7});
    load_word(16'd1, {`OP_LDI, `REG_2, 8'd5});
    load_word(16'd2, {`OP_ADD, `REG_3, `REG_1, `REG_2, 2'd0});
    load_word(16'd3, {`OP_GLAUNCH, 11'd20});
    load_word(16'd4, {`OP_GWAIT, 11'd5});
    load_word(16'd5, {`OP_HALT, 11'd0});

    // A short scalar/SIMT kernel: TID writes lane IDs to r4, then extra
    // instructions ensure the CPU observes RUNNING and enters GWAIT.
    load_word(16'd20, {`OP_TID, `REG_4, 8'd0});
    load_word(16'd21, {`OP_LDI, `REG_1, 8'd1});
    load_word(16'd22, {`OP_LDI, `REG_2, 8'd2});
    load_word(16'd23, {`OP_HALT, 11'd0});

    repeat (2) tick;
    reset = 1'b0;
    while (!halted && cycles < 40) begin
      tick;
      cycles = cycles + 1;
      if (dut.gpu_module.gpu_state == gpu_types::GPU_STATE_RUNNING)
        saw_gpu_running = 1'b1;
      if (dut.cpu_module.control_unit_module.fsm_out_state == `FSM_GPU_WAIT)
        saw_cpu_wait = 1'b1;
    end
    #1;

    if (!halted)
      $fatal(1, "chip did not halt its CPU/GPU integration program");
    if (dut.cpu_module.datapath.registers.data_out[`REG_3] !== 16'd12)
      $fatal(1, "chip CPU produced %0d instead of 12", dut.cpu_module.datapath.registers.data_out[2]);
    if (!saw_gpu_running)
      $fatal(1, "GLAUNCH never transitioned the GPU to RUNNING");
    if (!saw_cpu_wait)
      $fatal(1, "GWAIT did not stall the CPU while the GPU was running");
    if (dut.gpu_module.gpu_state !== gpu_types::GPU_STATE_IDLE)
      $fatal(1, "GPU did not return to IDLE after completing its kernel");
    if (dut.gpu_module.warp_module.datapath_module.warp_lanes[7].lane_module.reg_file.data_out[`REG_4]
        !== 16'd7)
      $fatal(1, "GPU did not execute TID from GLAUNCH address 20");

    $display("chip_tb passed");
    $finish;
  end
endmodule
