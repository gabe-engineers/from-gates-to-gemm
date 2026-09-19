`include "warp.sv"
`include "gpu_types.sv"

module gpu (
    input clk,
    input reset,
    input [7:0][15:0] mem_read_data,
    output gpu_types::warp_mem_request gpu_mem_request,
    output mem_write_enable
);

  warp warp_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(mem_read_data),
      .warp_mem_request(gpu_mem_request),
      .mem_write_enable(mem_write_enable)
  );

endmodule
