`include "decoder.v"
`include "program_counter.v"
`include "control_fsm.v"

module control_unit (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    input [15:0] datapath_read_data_a,
    input [15:0] datapath_read_data_b,
    output [8:0] mem_addr,
    output mem_write_enable,
    output datapath_write_enable,
    output datapath_writeback_select,
    output [3:0] alu_op,
    output [15:0] datapath_immediate,
    output [2:0] datapath_src_reg_a,
    output [2:0] datapath_src_reg_b,
    output [2:0] datapath_dst_reg,
    output halted
);

  wire [ 8:0] pc;
  wire        advance_pc;
  wire        write_enable_pc;
  reg         cmp_equal_flag;

  wire [ 2:0] fsm_out_state;

  wire [ 3:0] decoder_out_opcode;
  wire [ 2:0] decoder_out_dst_reg;
  wire [ 2:0] decoder_out_src_reg_a;
  wire [ 2:0] decoder_out_src_reg_b;
  wire [15:0] decoder_out_immediate;
  wire [ 8:0] decoder_out_address;
  wire        decoder_out_is_register_write_op;

  wire [15:0] ir;

  wire [15:0] datapath_write_reg_data;

  // FETCH/DECODE captures the memory word into the IR at the FETCH/DECODE -> EXECUTE edge.
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

  program_counter pc_module (
      .clk         (clk),
      .reset       (reset),
      .advance     (advance_pc),
      .write_enable(write_enable_pc),
      .write_data  (decoder_out_address),
      .data_out    (pc)
  );

  control_fsm fsm (
      .clk   (clk),
      .reset (reset),
      .opcode(decoder_out_opcode),
      .state(fsm_out_state)
  );

  // CMP is control flow state: it records equality for a later JE instruction.
  always @(posedge clk) begin
    if (reset)
      cmp_equal_flag <= 1'b0;
    else if (fsm_out_state == `FSM_EXECUTE && decoder_out_opcode == `OP_CMP)
      cmp_equal_flag <= datapath_read_data_a == datapath_read_data_b;
  end

  function is_execute_register_write_op(input [3:0] opcode);
    begin
      case (opcode)
        `OP_LDI, `OP_MOV, `OP_ADD, `OP_SUB, `OP_SHL, `OP_SHR, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR:
        is_execute_register_write_op = 1'b1;
        `OP_LOAD, `OP_STORE, `OP_CMP, `OP_JMP, `OP_JE, `OP_HALT:
        is_execute_register_write_op = 1'b0;
      endcase
    end
  endfunction

  function is_immediate_writeback_op(input [3:0] opcode);
    begin
      if (opcode == `OP_LOAD || opcode == `OP_LDI)
        is_immediate_writeback_op = 1'b1;
      else is_immediate_writeback_op = 1'b0;
    end
  endfunction

  assign datapath_immediate = decoder_out_opcode == `OP_LOAD && fsm_out_state == `FSM_MEMORY ? mem_read_data : decoder_out_immediate;

  // Normal writeback happens at the end of EXECUTE; LOAD writes back at the end of MEMORY.
  assign datapath_write_enable =
      (fsm_out_state == `FSM_EXECUTE && is_execute_register_write_op(decoder_out_opcode)) ||
      (fsm_out_state == `FSM_MEMORY && decoder_out_opcode == `OP_LOAD);

  assign mem_addr = fsm_out_state == `FSM_FETCH_DECODE ? pc : decoder_out_address;

  // The PC advances when the current instruction completes execution.
  assign advance_pc = fsm_out_state == `FSM_EXECUTE;

  assign write_enable_pc =
      fsm_out_state == `FSM_EXECUTE &&
      (decoder_out_opcode == `OP_JMP ||
       (decoder_out_opcode == `OP_JE && cmp_equal_flag));

  assign mem_write_enable = fsm_out_state == `FSM_MEMORY && decoder_out_opcode == `OP_STORE;

  assign datapath_src_reg_a = decoder_out_src_reg_a;

  assign datapath_src_reg_b = decoder_out_src_reg_b;

  assign datapath_dst_reg = decoder_out_dst_reg;

  assign halted = fsm_out_state == `FSM_HALT;

  assign datapath_writeback_select = is_immediate_writeback_op(decoder_out_opcode);

  assign alu_op = decoder_out_opcode;

endmodule
