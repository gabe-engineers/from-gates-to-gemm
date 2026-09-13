`include "cpu.v"
`include "ram.v"

module chip (
    input  clk,
    input  reset,
    output halted
);

  wire [15:0] cpu_in_mem_data;
  wire [15:0] cpu_out_mem_address;
  wire [15:0] cpu_out_mem_write_data;
  wire cpu_out_mem_write_enable;

  cpu cpu_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(cpu_in_mem_data),
      .mem_address(cpu_out_mem_address),
      .mem_write_data(cpu_out_mem_write_data),
      .mem_write_enable(cpu_out_mem_write_enable),
      .halted(halted)
  );

  memory memory_module (
      .clk(clk),
      .address(cpu_out_mem_address),
      .write_enable(cpu_out_mem_write_enable),
      .write_data(cpu_out_mem_write_data),
      .read_data(cpu_in_mem_data)
  );

endmodule
