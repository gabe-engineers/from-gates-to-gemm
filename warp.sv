`include "gpu_types.svh"

module warp (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    output [15:0] mem_read_address,
    output [15:0] mem_write_data,
    output [15:0] mem_write_address,
    output mem_write_enable
);

wire gpu_types::lane_request_t lane_requests [7:0];
wire gpu_types::lane_response_t lane_responses [7:0];

wire datapath_write_enable;
wire datapath_write_back_select;
wire alu_op;
wire [15:0] datapath_immediate;


warp_control_unit control_unit_module (
    .clk(clk),
    .reset(reset),
    .mem_read_data(mem_read_data),
    .datapath_write_enable(datapath_write_enable),
    .datapath_writeback_select(datapath_writeback_select),
    .alu_op(alu_op),
    .datapath_immediate(datapath_immediate),
    .datapath_src_reg_a(),
    .datapath_src_reg_b(),
    .datapath_dst_reg(),
    .lane_requests(lane_requests),
  );

warp_datapath datapath_module (
    .clk(clk),
    .reset(reset),
    .write_enable(datapath_write_enable),
    .writeback_select(datapath_writeback_select)
    .alu_op(alu_op),
    .immediate(),
    .lane_requests(),
    .lane_reponses()
  );

endmodule
