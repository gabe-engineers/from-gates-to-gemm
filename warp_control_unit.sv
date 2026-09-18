`include "gpu_types.sv"

module warp_control_unit (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    input gpu_types::lane_request_t lane_requests[7:0],
    output gpu_types::lane_response_t lane_responses[7:0]
);

  register ir_module (
      .clk         (clk),
      .reset       (reset),
      .write_enable(fsm_out_state == `FSM_FETCH_DECODE),
      .data_in     (mem_read_data),
      .data_out    (ir)
  );

  decoder decoder_module (
      .instruction_data(ir),
      .opcode          (decoder_out_opcode),
      .dst_reg         (decoder_out_dst_reg),
      .src_reg_a       (decoder_out_src_reg_a),
      .src_reg_b       (decoder_out_src_reg_b),
      .immediate       (decoder_out_immediate),
      .address         (decoder_out_address)
  );

  wrap_datapath datapath_module (
      .clk(clk),
      .reset(reset),
      .write_enable(),
      .writeback_select(),
      .alu_op(),
      .lane_requests(lane_requests),
      .lane_responses(lane_responses)
  );

endmodule
