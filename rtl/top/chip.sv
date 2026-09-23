`include "cpu.sv"
`include "cpu_types.svh"
`include "gpu.sv"
`include "memory.sv"
`include "gpu_types.svh"

module chip (
    input  clk,
    input  reset,
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

  memory memory_module (
      .clk(clk),
      .cpu_mem_request(cpu_mem_request),
      .cpu_read_data(cpu_mem_read_data),
      .gpu_read_response(gpu_mem_response),
      .gpu_mem_request(gpu_mem_request)
  );

endmodule
