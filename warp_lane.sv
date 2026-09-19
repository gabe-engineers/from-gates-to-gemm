`include "gpu_types.svh"
`include "control_helpers.svh"

module warp_lane (
    input clk,
    input reset,
    input [2:0] lane_id,
    input gpu_types::lane_request_t lane_request,
    output [15:0] out
);

  wire [15:0] alu_out;
  wire [15:0] read_reg_data_a;
  wire [15:0] read_reg_data_b;
  wire [15:0] dst_reg_data;
  wire [15:0] writeback_data;

  assign writeback_data =
      lane_request.writeback_source == control_helpers_pkg::WB_IMMEDIATE ?
          lane_request.immediate :
      lane_request.writeback_source == control_helpers_pkg::WB_THREAD_ID ?
          {13'b0, lane_id} : alu_out;
  assign out = writeback_data;

  register_file reg_file (
      .clk(clk),
      .reset(reset),
      .write_enable(lane_request.write_enable),
      .write_addr(lane_request.dst_reg),
      .write_data(writeback_data),
      .read_addr_a(lane_request.src_reg_a),
      .read_addr_b(lane_request.src_reg_b),
      .read_data_a(read_reg_data_a),
      .read_data_b(read_reg_data_b),
      .write_reg_data(dst_reg_data)
  );

  alu_16bit alu (
      .op (lane_request.alu_op),
      .a  (read_reg_data_a),
      .b  (read_reg_data_b),
      .out(alu_out)
  );

endmodule
