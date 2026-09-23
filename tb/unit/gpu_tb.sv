`include "register.sv"
`include "control_fsm.sv"
`include "register_file.sv"
`include "alu.sv"
`include "gpu.sv"

module gpu_tb;
  logic clk;
  logic reset;
  wire gpu_types::warp_mem_response_t mem_response;
  logic [15:0] instruction_memory [0:511];
  gpu_types::gpu_dispatch_t gpu_dispatch;
  wire gpu_types::gpu_state_t gpu_state;
  wire gpu_types::gpu_mem_request_t gpu_mem_request;

  wire [7:0][15:0] mem_read_data;

  for (genvar lane = 0; lane < 8; lane++) begin : memory_read_ports
    assign mem_read_data[lane] = instruction_memory[gpu_mem_request.address[lane]];
  end
  assign mem_response.read_data = mem_read_data;

  gpu dut (
      .clk(clk),
      .reset(reset),
      .mem_response(mem_response),
      .gpu_dispatch(gpu_dispatch),
      .gpu_state(gpu_state),
      .gpu_mem_request(gpu_mem_request)
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
    gpu_dispatch.command = gpu_types::GPU_COMMAND_NONE;
    gpu_dispatch.launch_address = 16'd23;
    for (int index = 0; index < 512; index++)
      instruction_memory[index] = {`OP_HALT, 11'd0};
    instruction_memory[23] = {`OP_LDI, 3'd0, 8'd1};
    instruction_memory[24] = {`OP_HALT, 11'd0};
    instruction_memory[100] = {`OP_LDI, 3'd0, 8'd2};
    instruction_memory[101] = {`OP_HALT, 11'd0};
    tick;

    reset = 1'b0;
    tick;
    if (gpu_state !== gpu_types::GPU_STATE_IDLE)
      $fatal(1, "GPU left IDLE without a launch command");
    if (gpu_mem_request.write_enable !== 1'b0)
      $fatal(1, "idle GPU issued a memory write request");
    if (dut.warp_module.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE)
      $fatal(1, "disabled warp advanced while GPU was idle");

    gpu_dispatch.command = gpu_types::GPU_COMMAND_LAUNCH;
    tick;
    if (gpu_state !== gpu_types::GPU_STATE_RUNNING)
      $fatal(1, "launch did not transition GPU from IDLE to RUNNING");
    if (gpu_mem_request.address[0] !== 16'd23)
      $fatal(1, "launch did not start fetching from its supplied address: got %0d",
             gpu_mem_request.address[0]);

    // A second launch while work is active is a no-op.
    gpu_dispatch.launch_address = 16'd100;
    tick;
    if (gpu_state !== gpu_types::GPU_STATE_RUNNING)
      $fatal(1, "launch while running changed the GPU state");
    if (gpu_mem_request.address[0] !== 16'd23)
      $fatal(1, "launch while running restarted the warp");

    gpu_dispatch.command = gpu_types::GPU_COMMAND_NONE;
    tick;
    if (gpu_state !== gpu_types::GPU_STATE_RUNNING)
      $fatal(1, "NONE changed the GPU state while work was active");
    if (gpu_mem_request.address[0] !== 16'd24)
      $fatal(1, "warp did not advance after executing its first instruction");

    // The HALT at address 24 completes the warp, then the controller returns
    // to IDLE on the following observed-halted cycle.
    repeat (3) tick;
    if (gpu_state !== gpu_types::GPU_STATE_IDLE)
      $fatal(1, "GPU did not return to IDLE after its warp halted");

    // An accepted launch resets the completed warp before it runs again.
    gpu_dispatch.command = gpu_types::GPU_COMMAND_LAUNCH;
    tick;
    if (gpu_state !== gpu_types::GPU_STATE_RUNNING)
      $fatal(1, "completed warp was not restarted by a new launch");
    if (gpu_mem_request.address[0] !== 16'd100)
      $fatal(1, "relaunch did not use its new start address");

    $display("gpu_tb passed");
    $finish;
  end
endmodule
