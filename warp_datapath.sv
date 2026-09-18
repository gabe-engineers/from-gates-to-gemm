`include "gpu_types.vh"

module warp_datapath (
    input                                    clk,
    input                                    reset,
    input                                    write_enable,
    input                                    writeback_select,       // ALU = 0, IMMEDIATE = 1
    input                             [ 3:0] alu_op,
    input                             [15:0] immediate,
    input  gpu_types::lane_request_t         lane_requests   [7:0],
    output gpu_types::lane_response_t        lane_reponses   [7:0]
);

  parameter int NUM_LANES = 8;

  generate
    for (genvar i = 0; i < NUM_LANES; i++) begin : warp_lanes

      warp_lane lane_module (
          .clk(clk),
          .reset(reset),
          .write_enable(write_enable),
          .writeback_select(writeback_select),
          .alu_op(alu_op),
          .immediate(immediate),
          .lane_request(lane_requests[i]),
          .lane_response(lane_responses[i])
      );

    end

  endgenerate

endmodule
