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

  wire [7:0][15:0] gpu_mem_read_data;
  wire gpu_types::warp_mem_request gpu_mem_request;
  wire gpu_types::gpu_command_t gpu_command;
  wire gpu_types::gpu_state_t gpu_state;
  wire [15:0] gpu_launch_address;

  cpu cpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(cpu_mem_read_data),
      .gpu_state(gpu_state),
      .mem_request(cpu_mem_request),
      .halted(halted),
      .gpu_command(gpu_command),
      .gpu_launch_address(gpu_launch_address)
  );

  gpu gpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(gpu_mem_read_data),
      .gpu_command(gpu_command),
      .gpu_launch_address(gpu_launch_address),
      .gpu_state(gpu_state),
      .gpu_mem_request(gpu_mem_request)
  );

  memory memory_module (
      .clk(clk),
      .cpu_mem_request(cpu_mem_request),
      .cpu_read_data(cpu_mem_read_data),
      .gpu_read_data(gpu_mem_read_data),
      .gpu_mem_request(gpu_mem_request)
  );

endmodule
