`include "cpu_types.svh"
`include "gpu_types.svh"

module chip #(
    parameter RAM_INIT_FILE = "",
    parameter RAM_INIT_PREFIX = "",
    parameter GEMM_SCRATCH_MODE = 1'b0
) (
    input clk,
    input reset,
    // Program load port, wired straight to the RAM. Hold reset while loading.
    input load_enable,
    input [15:0] load_address,
    input [15:0] load_data,
    input [15:0] inspect_address,
    output [15:0] inspect_data,
    output halted
);

  wire [15:0] cpu_mem_read_data;
  wire cpu_types_pkg::cpu_mem_request_t cpu_mem_request;

  wire gpu_types::gpu_mem_response_t gpu_mem_response;
  wire gpu_types::gpu_mem_request_t gpu_mem_request;
  wire gpu_types::gpu_dispatch_t gpu_dispatch;
  wire gpu_types::gpu_state_t gpu_state;

  cpu cpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(cpu_mem_read_data),
      .gpu_state(gpu_state),
      .mem_request(cpu_mem_request),
      .halted(halted),
      .gpu_dispatch(gpu_dispatch)
  );

  gpu gpu_module (
      .clk(clk),
      .reset(reset),
      .mem_response(gpu_mem_response),
      .gpu_dispatch(gpu_dispatch),
      .gpu_state(gpu_state),
      .gpu_mem_request(gpu_mem_request)
  );

  memory #(
      .INIT_FILE(RAM_INIT_FILE),
      .INIT_PREFIX(RAM_INIT_PREFIX),
      .GEMM_SCRATCH_MODE(GEMM_SCRATCH_MODE)
  ) memory_module (
      .clk(clk),
      .reset(reset),
      .cpu_mem_request(cpu_mem_request),
      .cpu_read_data(cpu_mem_read_data),
      .gpu_read_response(gpu_mem_response),
      .gpu_mem_request(gpu_mem_request),
      .gpu_active(gpu_state == gpu_types::GPU_STATE_RUNNING),
      .inspect_enable(halted),
      .load_enable(load_enable),
      .load_address(load_address),
      .load_data(load_data),
      .inspect_address(inspect_address),
      .inspect_data(inspect_data)
  );

endmodule
