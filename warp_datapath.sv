`include "gpu_types.svh"
`include "warp_lane.sv"

module warp_datapath (
    input                                   clk,
    input                                   reset,
    input  gpu_types::lane_request_t        lane_request,
    output                    [7:0][15:0] lane_responses
);

  parameter int NUM_LANES = 8;

  generate
    for (genvar i = 0; i < NUM_LANES; i++) begin : warp_lanes
      localparam logic [2:0] LANE_ID = i;

      warp_lane lane_module (
          .clk(clk),
          .reset(reset),
          .lane_id(LANE_ID),
          .lane_request(lane_request),
          .out(lane_responses[i])
      );

    end

  endgenerate

endmodule
