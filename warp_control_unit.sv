`include "gpu_types.svh"
`include "cpu_types.svh"
`include "fsm_states.svh"
`include "control_helpers.svh"

module warp_control_unit (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    output wire gpu_types::lane_request_t out
);

  wire [2:0] fsm_out_state;
  wire cpu_types_pkg::decoder_out_t decoder_out;
  wire [15:0] ir;

  assign out.alu_op = decoder_out.opcode[3:0];
  assign out.writeback_source =
      control_helpers_pkg::writeback_source_for_opcode(decoder_out.opcode);

  assign out.write_enable =
      (fsm_out_state == `FSM_EXECUTE &&
       control_helpers_pkg::is_execute_register_write_op(decoder_out.opcode)) ||
      (fsm_out_state == `FSM_MEMORY && decoder_out.opcode == `OP_LOAD);

  assign out.dst_reg = decoder_out.dst_reg;
  assign out.src_reg_a = decoder_out.src_reg_a;
  assign out.src_reg_b = decoder_out.src_reg_b;
  assign out.immediate = decoder_out.immediate;
  assign out.jmp_address = decoder_out.address;

  register ir_module (
      .clk         (clk),
      .reset       (reset),
      .write_enable(fsm_out_state == `FSM_FETCH_DECODE),
      .data_in     (mem_read_data),
      .data_out    (ir)
  );

  decoder decoder_module (
      .instruction_data(ir),
      .out             (decoder_out)
  );

  control_fsm fsm (
      .clk            (clk),
      .reset          (reset),
      .opcode         (decoder_out.opcode),
      .memory_complete(1'b1),
      .state          (fsm_out_state)
  );

endmodule
