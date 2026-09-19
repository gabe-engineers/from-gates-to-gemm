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

  cpu cpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(cpu_mem_read_data),
      .mem_request(cpu_mem_request),
      .halted(halted)
  );

  gpu gpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(gpu_mem_read_data),
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
