`include "cpu.sv"
`include "gpu.sv"
`include "memory.sv"
`include "gpu_types.sv"

module chip (
    input  clk,
    input  reset,
    output halted
);

  wire [15:0] cpu_in_mem_data;
  wire [15:0] cpu_out_mem_address;
  wire [15:0] cpu_out_mem_write_data;
  wire cpu_out_mem_write_enable;

  wire [7:0][15:0] gpu_in_mem_data;
  wire gpu_out_mem_write_enable;
  wire gpu_types::warp_mem_request gpu_out_mem_request;

  cpu cpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(cpu_in_mem_data),
      .mem_address(cpu_out_mem_address),
      .mem_write_data(cpu_out_mem_write_data),
      .mem_write_enable(cpu_out_mem_write_enable),
      .halted(halted)
  );

  gpu gpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(gpu_in_mem_data),
      .gpu_mem_request(gpu_out_mem_request),
      .mem_write_enable(gpu_out_mem_write_enable)
  );

  memory memory_module (
      .clk(clk),
      .cpu_address(cpu_out_mem_address),
      .cpu_write_enable(cpu_out_mem_write_enable),
      .cpu_write_data(cpu_out_mem_write_data),
      .cpu_read_data(cpu_in_mem_data),
      .gpu_write_enable(gpu_out_mem_write_enable),
      .gpu_read_data(gpu_in_mem_data),
      .gpu_mem_request(gpu_out_mem_request)
  );

endmodule
