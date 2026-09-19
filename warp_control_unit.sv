`include "gpu_types.sv"
`include "fsm_states.svh"
`include "control_helpers.svh"

module warp_control_unit (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    output wire gpu_types::lane_request_t out
);

  wire [2:0] fsm_out_state;
  wire [4:0] decoder_out_opcode;
  wire [15:0] ir;

  assign out.alu_op = decoder_out_opcode[3:0];
  assign out.writeback_source =
      control_helpers_pkg::writeback_source_for_opcode(decoder_out_opcode);

  assign out.write_enable =
      (fsm_out_state == `FSM_EXECUTE &&
       control_helpers_pkg::is_execute_register_write_op(decoder_out_opcode)) ||
      (fsm_out_state == `FSM_MEMORY && decoder_out_opcode == `OP_LOAD);

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
      .dst_reg         (out.dst_reg),
      .src_reg_a       (out.src_reg_a),
      .src_reg_b       (out.src_reg_b),
      .immediate       (out.immediate),
      .address         (out.jmp_address)
  );

  control_fsm fsm (
      .clk            (clk),
      .reset          (reset),
      .opcode         (decoder_out_opcode),
      .memory_complete(1'b1),
      .state          (fsm_out_state)
  );

endmodule
