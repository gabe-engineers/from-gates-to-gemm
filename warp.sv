`include "gpu_types.sv"
`include "warp_control_unit.sv"
`include "warp_datapath.sv"

module warp (
    input clk,
    input reset,
    input [7:0][15:0] mem_read_data,
    output gpu_types::warp_mem_request warp_mem_request,
    output mem_write_enable
);

  wire gpu_types::lane_request_t lane_request;
  wire [7:0][15:0] lane_responses;

  warp_control_unit control_unit_module (
      .clk(clk),
      .reset(reset),
      .mem_read_data(mem_read_data[0]),
      .out(lane_request)
  );

  warp_datapath datapath_module (
      .clk(clk),
      .reset(reset),
      .lane_request(lane_request),
      .lane_responses(lane_responses)
  );

endmodule
