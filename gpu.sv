`include "warp.sv"

module gpu (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    output [15:0] mem_read_address,
    output [15:0] mem_write_data,
    output [15:0] mem_write_address,
    output mem_write_enable
);

  warp warp_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(mem_read_data),
      .mem_read_address(mem_read_address),
      .mem_write_data(mem_write_data),
      .mem_write_address(mem_write_address),
      .mem_write_enable(mem_write_enable)
  );

endmodule
