`include "cpu.sv"
`include "tb_regs.svh"

module cpu_tb;
  logic clk;
  logic reset;
  logic [15:0] memory[0:65535];
  wire [15:0] mem_read_data;
  wire cpu_types_pkg::cpu_mem_request_t mem_request;
  wire halted;
  wire gpu_types::gpu_dispatch_t gpu_dispatch;
  gpu_types::gpu_state_t gpu_state;
  integer cycles;

  cpu dut (
      .clk          (clk),
      .reset        (reset),
      .mem_read_data(mem_read_data),
      .gpu_state    (gpu_state),
      .mem_request  (mem_request),
      .halted       (halted),
      .gpu_dispatch (gpu_dispatch)
  );
  assign mem_read_data = memory[mem_request.address];
  always #5 clk = ~clk;
  always @(posedge clk)
    if (mem_request.write_enable) memory[mem_request.address] <= mem_request.write_data;

  initial begin
    clk = 0;
    reset = 1;
    gpu_state = gpu_types::GPU_STATE_IDLE;
    cycles = 0;

    memory[0] = {`OP_LUI, `REG_1, 8'h12};
    memory[1] = {`OP_LDI, `REG_3, 8'h34};
    memory[2] = {`OP_OR, `REG_1, `REG_1, `REG_3, 2'd0};
    memory[3] = {`OP_LDI, `REG_4, 8'hAA};
    memory[4] = {`OP_STORE, `REG_1, `REG_4, 5'd0};
    memory[5] = {`OP_LOAD, `REG_5, `REG_1, 5'd0};
    memory[6] = {`OP_CMP, `REG_4, `REG_5, 5'd0};
    memory[7] = {`OP_JE, 11'd9};
    memory[8] = {`OP_HALT, 11'd0};
    memory[9] = {`OP_LDI, `REG_6, 8'd16};
    memory[10] = {`OP_SHR, `REG_7, `REG_1, `REG_6, 2'd0};
    memory[11] = {`OP_LDI, `REG_8, 8'hFF};
    memory[12] = {`OP_TID, `REG_8, 8'd0};
    memory[13] = {`OP_JMP, 11'h7FF};
    memory[2047] = {`OP_HALT, 11'd0};
    memory[16'h1234] = 16'd0;

    repeat (2) @(posedge clk);
    reset = 0;
    while (!halted && cycles < 100) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    #1;

    assert (halted)
    else $fatal(1, "CPU did not halt");
    assert (memory[16'h1234] === 16'h00AA)
    else $fatal(1, "16-bit STORE address failed");
    assert (dut.datapath.registers.data_out[`REG_5] === 16'h00AA)
    else $fatal(1, "LOAD failed");
    assert (dut.datapath.registers.data_out[`REG_7] === 16'h0000)
    else $fatal(1, "wide SHR failed");
    assert (dut.datapath.registers.data_out[`REG_8] === 16'h0000)
    else $fatal(1, "TID did not return zero on the scalar CPU");
    assert (dut.control_unit_module.ir === {`OP_HALT, 11'd0})
    else $fatal(1, "addr11 jump did not fetch address 2047");

    // HALT must not clear or otherwise modify registers.
    repeat (3) @(posedge clk);
    #1;
    if (dut.datapath.registers.data_out[`REG_1] !== 16'h1234 ||
        dut.datapath.registers.data_out[`REG_5] !== 16'h00AA)
      $fatal(1, "HALT changed registers");

    // GPU commands are visible only while their instruction executes.
    reset = 1'b1;
    memory[0] = {`OP_GLAUNCH, 11'd23};
    @(posedge clk);
    #1;
    reset = 1'b0;

    @(posedge clk);
    #1;
    if (gpu_dispatch.command !== gpu_types::GPU_COMMAND_LAUNCH)
      $fatal(1, "GLAUNCH was not forwarded to the CPU GPU-command output");
    if (gpu_dispatch.launch_address !== 16'd23)
      $fatal(1, "GLAUNCH did not forward its start address");

    @(posedge clk);
    #1;
    if (gpu_dispatch.command !== gpu_types::GPU_COMMAND_NONE)
      $fatal(1, "GPU command remained asserted outside EXECUTE");
    if (gpu_dispatch.launch_address !== 16'd0)
      $fatal(1, "GPU launch address remained asserted outside EXECUTE");

    // GWAIT is CPU-local: it stalls while the GPU is running, then jumps to
    // its addr11 operand after the GPU broadcasts IDLE.
    reset = 1'b1;
    gpu_state = gpu_types::GPU_STATE_RUNNING;
    memory[0] = {`OP_GWAIT, 11'd1};
    memory[1] = {`OP_LDI, `REG_1, 8'd77};
    memory[2] = {`OP_HALT, 11'd0};
    @(posedge clk);
    #1;
    reset = 1'b0;

    @(posedge clk);
    #1;
    @(posedge clk);
    #1;
    if (dut.control_unit_module.fsm_out_state !== `FSM_GPU_WAIT)
      $fatal(1, "GWAIT did not stall the CPU while the GPU was running");
    if (gpu_dispatch.command !== gpu_types::GPU_COMMAND_NONE)
      $fatal(1, "GWAIT emitted a GPU command");

    repeat (2) @(posedge clk);
    #1;
    if (dut.control_unit_module.fsm_out_state !== `FSM_GPU_WAIT)
      $fatal(1, "CPU advanced while GPU remained running");

    gpu_state = gpu_types::GPU_STATE_IDLE;
    @(posedge clk);
    #1;
    if (dut.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE)
      $fatal(1, "CPU did not leave GWAIT after the GPU became idle");

    cycles = 0;
    while (!halted && cycles < 20) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    #1;
    if (!halted)
      $fatal(1, "CPU did not resume and halt after GWAIT");
    if (dut.datapath.registers.data_out[`REG_1] !== 16'd77)
      $fatal(1, "CPU did not execute the instruction after GWAIT");

    $display("cpu_tb passed");
    $finish;
  end
endmodule
