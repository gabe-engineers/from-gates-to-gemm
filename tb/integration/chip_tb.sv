`include "chip.sv"
`include "tb_regs.svh"

module chip_tb;
  logic clk;
  logic reset;
  wire halted;
  integer cycles;
  logic saw_cpu_wait;
  logic saw_gpu_running;

  chip dut (
      .clk(clk),
      .reset(reset),
      .load_enable(1'b0),
      .load_address(16'b0),
      .load_data(16'b0),
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

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    cycles = 0;
    saw_cpu_wait = 1'b0;
    saw_gpu_running = 1'b0;

    // The RAM has no external preload port, so this end-to-end program is
    // fixed into its implementation registers. It proves that GLAUNCH's
    // address reaches the warp instruction fetch path through chip.
    force dut.memory_module.memory_words[0].register.data_out = {`OP_LDI, `REG_1, 8'd7};
    force dut.memory_module.memory_words[1].register.data_out = {`OP_LDI, `REG_2, 8'd5};
    force dut.memory_module.memory_words[2].register.data_out =
        {`OP_ADD, `REG_3, `REG_1, `REG_2, 2'd0};
    force dut.memory_module.memory_words[3].register.data_out = {`OP_GLAUNCH, 11'd20};
    force dut.memory_module.memory_words[4].register.data_out = {`OP_GWAIT, 11'd5};
    force dut.memory_module.memory_words[5].register.data_out = {`OP_HALT, 11'd0};

    // A short scalar/SIMT kernel: TID writes lane IDs to r4, then extra
    // instructions ensure the CPU observes RUNNING and enters GWAIT.
    force dut.memory_module.memory_words[20].register.data_out = {`OP_TID, `REG_4, 8'd0};
    force dut.memory_module.memory_words[21].register.data_out = {`OP_LDI, `REG_1, 8'd1};
    force dut.memory_module.memory_words[22].register.data_out = {`OP_LDI, `REG_2, 8'd2};
    force dut.memory_module.memory_words[23].register.data_out = {`OP_HALT, 11'd0};

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
