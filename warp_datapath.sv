`include "gpu_types.svh"
`include "warp_lane.sv"

module warp_datapath (
    input                                            clk,
    input                                            reset,
    input  gpu_types::warp_request_t                 warp_request,
    input  gpu_types::gpu_mem_response_t             mem_response,
    output                               [7:0][15:0] lane_responses,
    output gpu_types::warp_lane_status_t             lane_status,
    output                               [7:0][15:0] lane_mem_address,
    output                               [7:0][15:0] lane_mem_write_data
);

  parameter int NUM_LANES = 8;

  wire [NUM_LANES-1:0] operands_equal;

  generate
    for (genvar i = 0; i < NUM_LANES; i++) begin : warp_lanes
      localparam logic [2:0] LANE_ID = i;
      wire gpu_types::warp_lane_response_t lane_response;

      warp_lane lane_module (
          .clk(clk),
          .reset(reset),
          .lane_id(LANE_ID),
          .warp_request(warp_request),
          .mem_read_data(mem_response.read_data[i]),
          .response(lane_response)
      );

      assign lane_responses[i] = lane_response.value;
      assign operands_equal[i] = lane_response.operands_equal;
      assign lane_mem_address[i] = lane_response.mem_address;
      assign lane_mem_write_data[i] = lane_response.mem_write_data;
    end

  endgenerate

  assign lane_status.operands_equal = &operands_equal;
  assign lane_status.diverged = |operands_equal & ~&operands_equal;

endmodule
