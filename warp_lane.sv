`include "gpu_types.svh"
`include "control_helpers.svh"

module warp_lane (
    input clk,
    input reset,
    input [2:0] lane_id,
    input gpu_types::warp_request_t warp_request,
    input [15:0] mem_read_data,
    output gpu_types::warp_lane_response_t response
);

  wire [15:0] alu_out;
  wire [15:0] read_reg_data_a;
  wire [15:0] read_reg_data_b;
  wire [15:0] dst_reg_data;
  wire [15:0] writeback_data;

  assign writeback_data =
      warp_request.writeback_source == control_helpers_pkg::WB_MEMORY ?
          mem_read_data :
      warp_request.writeback_source == control_helpers_pkg::WB_IMMEDIATE ?
          warp_request.immediate :
      warp_request.writeback_source == control_helpers_pkg::WB_THREAD_ID ?
          {13'b0, lane_id} : alu_out;
  assign response.value = writeback_data;
  assign response.operands_equal = read_reg_data_a == read_reg_data_b;
  assign response.mem_address = read_reg_data_b;
  assign response.mem_write_data = read_reg_data_a;

  register_file reg_file (
      .clk(clk),
      .reset(reset),
      .write_enable(warp_request.write_enable),
      .write_addr(warp_request.dst_reg),
      .write_data(writeback_data),
      .read_addr_a(warp_request.src_reg_a),
      .read_addr_b(warp_request.src_reg_b),
      .read_data_a(read_reg_data_a),
      .read_data_b(read_reg_data_b),
      .write_reg_data(dst_reg_data)
  );

  alu_16bit alu (
      .operation(warp_request.alu_op),
      .operand_a(read_reg_data_a),
      .operand_b(read_reg_data_b),
      .result(alu_out)
  );

endmodule
