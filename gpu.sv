`include "warp.sv"
`include "gpu_types.svh"

module gpu (
    input clk,
    input reset,
    input [7:0][15:0] mem_read_data,
    input gpu_types::gpu_command_t gpu_command,
    input [15:0] gpu_launch_address,
    output gpu_types::gpu_state_t gpu_state,
    output gpu_types::warp_mem_request gpu_mem_request
);

  wire warp_enabled = gpu_state == gpu_types::GPU_STATE_RUNNING;
  wire launch_accepted =
      !reset &&
      gpu_state == gpu_types::GPU_STATE_IDLE &&
      gpu_command == gpu_types::GPU_COMMAND_LAUNCH;
  wire warp_halted;
  wire gpu_types::warp_mem_request raw_warp_mem_request;

  // The GPU owns dispatch lifetime. A command only starts an idle GPU;
  // another launch while work is active is deliberately a no-op.
  always @(posedge clk) begin
    if (reset)
      gpu_state <= gpu_types::GPU_STATE_IDLE;
    else case (gpu_state)
      gpu_types::GPU_STATE_IDLE: begin
        if (gpu_command == gpu_types::GPU_COMMAND_LAUNCH)
          gpu_state <= gpu_types::GPU_STATE_RUNNING;
      end
      gpu_types::GPU_STATE_RUNNING: begin
        if (warp_halted) gpu_state <= gpu_types::GPU_STATE_IDLE;
      end
      default: gpu_state <= gpu_types::GPU_STATE_IDLE;
    endcase
  end

  warp warp_module (
      .clk(clk),
      .reset(reset),
      .start(launch_accepted),
      .start_address(gpu_launch_address),
      .enable(warp_enabled),
      .mem_read_data(mem_read_data),
      .halted(warp_halted),
      .warp_mem_request(raw_warp_mem_request)
  );

  // A dormant GPU must not issue memory requests even if a future warp
  // implementation leaves stale request fields behind.
  assign gpu_mem_request = warp_enabled ? raw_warp_mem_request : '0;

endmodule
