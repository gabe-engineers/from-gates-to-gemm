`include "gpu_types.svh"
`include "warp_control_unit.sv"
`include "warp_datapath.sv"

module warp (
    input clk,
    input reset,
    input start,
    input [15:0] start_address,
    input enable,
    input [7:0][15:0] mem_read_data,
    output halted,
    output gpu_types::warp_mem_request warp_mem_request
);

  wire gpu_types::lane_request_t lane_request;
  wire [7:0][15:0] lane_responses;
  wire warp_reset = reset || start;
  wire [15:0] reset_address = start ? start_address : 16'b0;
  wire [15:0] instruction_address;

  warp_control_unit control_unit_module (
      .clk(clk),
      .reset(warp_reset),
      .start_address(reset_address),
      .enable(enable),
      .mem_read_data(mem_read_data[0]),
      .halted(halted),
      .instruction_address(instruction_address),
      .out(lane_request)
  );

  warp_datapath datapath_module (
      .clk(clk),
      .reset(warp_reset),
      .lane_request(lane_request),
      .lane_responses(lane_responses)
  );

  // Until warp data-memory instructions are implemented, every lane reads the
  // common instruction word selected by the warp PC.
  assign warp_mem_request = {1'b0, {8{instruction_address}}, 128'b0};

endmodule
