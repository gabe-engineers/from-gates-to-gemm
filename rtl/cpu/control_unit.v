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
    output        vector_write_enable,
    output [2:0] vector_write_addr,
    output [2:0] vector_write_lane,
    output [15:0] vector_write_data,
    output [2:0] vector_read_addr,
    output [2:0] vector_read_lane,
    output        vector_store_active,
    output        vector_alu_write_enable,
    output [2:0] vector_alu_write_addr,
    output [2:0] vector_alu_operation,
    output [2:0] vector_alu_read_addr_a,
    output [2:0] vector_alu_read_addr_b,
    output        datapath_vector_dot_writeback_select,
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
  wire        decoder_out_memory_vectorized;
  wire [ 2:0] decoder_out_halt_or_vector_subop;
  wire        decoder_out_is_register_write_op;
  reg  [ 2:0] vector_lane;

  wire is_vector_memory_operation =
      decoder_out_memory_vectorized &&
      (decoder_out_opcode == `OP_LOAD || decoder_out_opcode == `OP_STORE);
  wire is_vector_alu_operation =
      decoder_out_opcode == `OP_HALT_OR_VECTOR &&
      (decoder_out_halt_or_vector_subop == `HALT_OR_VECTOR_SUBOP_VADD ||
       decoder_out_halt_or_vector_subop == `HALT_OR_VECTOR_SUBOP_VSUB ||
       decoder_out_halt_or_vector_subop == `HALT_OR_VECTOR_SUBOP_VMUL);
  wire is_vector_dot_operation =
      decoder_out_opcode == `OP_HALT_OR_VECTOR &&
      decoder_out_halt_or_vector_subop == `HALT_OR_VECTOR_SUBOP_VDOT;
  wire vector_memory_complete =
      !is_vector_memory_operation || vector_lane == 3'd7;
  wire [8:0] vector_memory_address =
      datapath_read_data_b[8:0] + {6'b000000, vector_lane};

  wire [15:0] ir;

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
      .address         (decoder_out_address),
      .memory_vectorized(decoder_out_memory_vectorized),
      .halt_or_vector_subop(decoder_out_halt_or_vector_subop)
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
      .memory_complete(vector_memory_complete),
      .halt_or_vector_subop(decoder_out_halt_or_vector_subop),
      .state(fsm_out_state)
  );

  always @(posedge clk) begin
    if (reset)
      vector_lane <= 3'd0;
    else if (fsm_out_state == `FSM_EXECUTE && is_vector_memory_operation)
      vector_lane <= 3'd0;
    else if (fsm_out_state == `FSM_MEMORY && is_vector_memory_operation && vector_lane != 3'd7)
      vector_lane <= vector_lane + 3'd1;
    else if (fsm_out_state == `FSM_MEMORY && !is_vector_memory_operation)
      vector_lane <= 3'd0;
  end

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
        `OP_LOAD, `OP_STORE, `OP_CMP, `OP_JMP, `OP_JE, `OP_HALT_OR_VECTOR:
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

  assign datapath_immediate =
      (decoder_out_opcode == `OP_LOAD && !decoder_out_memory_vectorized &&
       fsm_out_state == `FSM_MEMORY) ? mem_read_data : decoder_out_immediate;

  // Normal writeback happens at the end of EXECUTE; LOAD writes back at the end of MEMORY.
  assign datapath_write_enable =
      (fsm_out_state == `FSM_EXECUTE && is_execute_register_write_op(decoder_out_opcode)) ||
      (fsm_out_state == `FSM_EXECUTE && is_vector_dot_operation) ||
      (fsm_out_state == `FSM_MEMORY && decoder_out_opcode == `OP_LOAD &&
       !decoder_out_memory_vectorized);

  // LOAD and STORE use the low nine bits of their scalar address-register operand.
  // VLOAD and VSTORE add the active lane number to form each consecutive address.
  assign mem_addr =
      fsm_out_state == `FSM_FETCH_DECODE ? pc :
      (decoder_out_opcode == `OP_LOAD || decoder_out_opcode == `OP_STORE ?
       (is_vector_memory_operation ? vector_memory_address : datapath_read_data_b[8:0]) :
       decoder_out_address);

  // The PC advances when the current instruction completes execution.
  assign advance_pc = fsm_out_state == `FSM_EXECUTE;

  assign write_enable_pc =
      fsm_out_state == `FSM_EXECUTE &&
      (decoder_out_opcode == `OP_JMP ||
       (decoder_out_opcode == `OP_JE && cmp_equal_flag));

  assign mem_write_enable = fsm_out_state == `FSM_MEMORY && decoder_out_opcode == `OP_STORE;

  assign vector_write_enable =
      fsm_out_state == `FSM_MEMORY && decoder_out_opcode == `OP_LOAD &&
      decoder_out_memory_vectorized;
  assign vector_write_addr = decoder_out_dst_reg;
  assign vector_write_lane = vector_lane;
  assign vector_write_data = mem_read_data;

  assign vector_read_addr = decoder_out_src_reg_a;
  assign vector_read_lane = vector_lane;
  assign vector_store_active =
      fsm_out_state == `FSM_MEMORY && decoder_out_opcode == `OP_STORE &&
      decoder_out_memory_vectorized;

  assign vector_alu_write_enable =
      fsm_out_state == `FSM_EXECUTE && is_vector_alu_operation;
  assign vector_alu_write_addr = decoder_out_dst_reg;
  assign vector_alu_operation = decoder_out_halt_or_vector_subop;
  assign vector_alu_read_addr_a = decoder_out_src_reg_a;
  assign vector_alu_read_addr_b = decoder_out_src_reg_b;
  assign datapath_vector_dot_writeback_select =
      fsm_out_state == `FSM_EXECUTE && is_vector_dot_operation;

  assign datapath_src_reg_a = decoder_out_src_reg_a;

  assign datapath_src_reg_b = decoder_out_src_reg_b;

  assign datapath_dst_reg = decoder_out_dst_reg;

  assign halted = fsm_out_state == `FSM_HALT_OR_VECTOR;

  assign datapath_writeback_select =
      is_immediate_writeback_op(decoder_out_opcode) && !decoder_out_memory_vectorized;

  assign alu_op = decoder_out_opcode;

endmodule
