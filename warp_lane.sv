`include "gpu_types.svh"

module warp_lane (
    input clk,
    input reset,
    input write_enable,
    input writeback_select,
    input [3:0] alu_op,
    input [15:0] immediate,
    input gpu_types::lane_request_t lane_request,
    output gpu_types::lane_response_t lane_response
);

  register_file reg_file (
      .clk(clk),
      .reset(reset),
      .write_enable(write_enable),
      .write_addr(),
      .write_data(),
      .read_addr_a(),
      .read_addr_b(),
      .read_data_a(),
      .read_data_b(),
      .write_reg_data()
  );

  alu_16bit alu ();

endmodule
