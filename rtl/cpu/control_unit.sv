`include "cpu_types.svh"
`include "decoder.sv"
`include "program_counter.sv"
`include "control_fsm.sv"
`include "control_helpers.svh"

module control_unit (
    input                                                clk,
    input                                                reset,
    input                                         [15:0] mem_read_data,
    input                                         [15:0] datapath_read_data_a,
    input                                         [15:0] datapath_read_data_b,
    input                                                datapath_zero_flag,
    input                                                datapath_less_than_flag,
    input gpu_types::gpu_state_t                         gpu_state,
    output wire cpu_types_pkg::control_unit_out_t        out
);

  wire [15:0] pc;
  wire advance_pc;
  wire write_enable_pc;
  logic cmp_equal_flag;
  logic cmp_less_flag;

  wire [2:0] fsm_out_state;
  wire gpu_busy = gpu_state == gpu_types::GPU_STATE_RUNNING;

  wire cpu_types_pkg::decoder_out_t decoder_out;
  logic [2:0] vector_lane;

  wire is_vector_memory_operation = decoder_out.opcode == `OP_VLD || decoder_out.opcode == `OP_VST;
  wire is_vector_alu_operation =
      decoder_out.opcode == `OP_VADD || decoder_out.opcode == `OP_VSUB ||
      decoder_out.opcode == `OP_VMUL;
  wire is_vector_dot_operation = decoder_out.opcode == `OP_VDOT;
  wire vector_memory_complete = !is_vector_memory_operation || vector_lane == 3'd7;
  wire [15:0] vector_memory_address = datapath_read_data_b + {13'b0, vector_lane};

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
      .out             (decoder_out)
  );

  // JR takes its target from a register; every other PC load uses the decoded
  // address field (JMP/JZ/JLT, GWAIT resume).
  wire [15:0] pc_write_data =
      decoder_out.opcode == `OP_JR ? datapath_read_data_a : decoder_out.address;

  program_counter pc_module (
      .clk         (clk),
      .reset       (reset),
      .advance     (advance_pc),
      .write_enable(write_enable_pc),
      .write_data  (pc_write_data),
      .data_out    (pc)
  );

  control_fsm fsm (
      .clk   (clk),
      .reset (reset),
      .enable(1'b1),
      .opcode(decoder_out.opcode),
      .instruction_valid(1'b1),
      .memory_complete(vector_memory_complete),
      .gpu_busy(gpu_busy),
      .state(fsm_out_state)
  );

  always @(posedge clk) begin
    if (reset) vector_lane <= 3'd0;
    else if (fsm_out_state == `FSM_EXECUTE && is_vector_memory_operation) vector_lane <= 3'd0;
    else if (fsm_out_state == `FSM_MEMORY && is_vector_memory_operation && vector_lane != 3'd7)
      vector_lane <= vector_lane + 3'd1;
    else if (fsm_out_state == `FSM_MEMORY && !is_vector_memory_operation) vector_lane <= 3'd0;
  end

  // CMP is control flow state. The ALU computes the comparison flags and the
  // control unit latches them for a later conditional branch (JZ reads equal,
  // a JL-style opcode would read less_than_flag).
  always @(posedge clk) begin
    if (reset) begin
      cmp_equal_flag <= 1'b0;
      cmp_less_flag <= 1'b0;
    end else if (fsm_out_state == `FSM_EXECUTE && decoder_out.opcode == `OP_CMP) begin
      cmp_equal_flag <= datapath_zero_flag;
      cmp_less_flag <= datapath_less_than_flag;
    end
  end

  assign out.datapath_immediate =
      (decoder_out.opcode == `OP_LOAD &&
       fsm_out_state == `FSM_MEMORY) ? mem_read_data :
      decoder_out.immediate;

  // Normal writeback happens at the end of EXECUTE; LOAD writes back at the end of MEMORY.
  assign out.datapath_write_enable =
      (fsm_out_state == `FSM_EXECUTE &&
       control_helpers_pkg::is_execute_register_write_op(
      decoder_out.opcode
  )) || (fsm_out_state == `FSM_EXECUTE && is_vector_dot_operation) ||
      (fsm_out_state == `FSM_MEMORY && decoder_out.opcode == `OP_LOAD);

  // Register-held addresses are 16 bits. VLD and VST add the active lane number
  // to form each consecutive word address.
  assign out.mem_addr =
      fsm_out_state == `FSM_FETCH_DECODE ? pc :
      (decoder_out.opcode == `OP_LOAD || decoder_out.opcode == `OP_STORE ||
       decoder_out.opcode == `OP_VLD || decoder_out.opcode == `OP_VST ?
       (is_vector_memory_operation ? vector_memory_address : datapath_read_data_b) :
       decoder_out.address);

  // The PC advances when the current instruction completes execution.
  assign advance_pc = fsm_out_state == `FSM_EXECUTE;

  // GWAIT stalls until the GPU is idle and then loads its addr11 operand into
  // the PC. The IR still holds GWAIT across GPU_WAIT, so the resume address
  // remains valid on the cycle the wait completes.
  wire is_gwait = decoder_out.opcode == `OP_GWAIT;
  wire gwait_resume =
      is_gwait && !gpu_busy &&
      (fsm_out_state == `FSM_EXECUTE || fsm_out_state == `FSM_GPU_WAIT);

  assign write_enable_pc =
      (fsm_out_state == `FSM_EXECUTE &&
       (decoder_out.opcode == `OP_JMP ||
        decoder_out.opcode == `OP_JR ||
        (decoder_out.opcode == `OP_JZ && cmp_equal_flag) ||
        (decoder_out.opcode == `OP_JLT && cmp_less_flag))) ||
      gwait_resume;

  assign out.mem_write_enable = fsm_out_state == `FSM_MEMORY &&
      (decoder_out.opcode == `OP_STORE || decoder_out.opcode == `OP_VST);

  assign out.vector_write_enable = fsm_out_state == `FSM_MEMORY && decoder_out.opcode == `OP_VLD;
  assign out.vector_write_addr = decoder_out.dst_reg;
  assign out.vector_write_lane = vector_lane;
  assign out.vector_write_data = mem_read_data;

  assign out.vector_read_addr = decoder_out.src_reg_a;
  assign out.vector_read_lane = vector_lane;
  assign out.vector_store_active = fsm_out_state == `FSM_MEMORY && decoder_out.opcode == `OP_VST;

  assign out.vector_alu_write_enable = fsm_out_state == `FSM_EXECUTE && is_vector_alu_operation;
  assign out.vector_alu_write_addr = decoder_out.dst_reg;
  assign out.vector_alu_operation = decoder_out.opcode;
  assign out.vector_alu_read_addr_a = decoder_out.src_reg_a;
  assign out.vector_alu_read_addr_b = decoder_out.src_reg_b;
  assign out.datapath_vector_dot_writeback_select =
      fsm_out_state == `FSM_EXECUTE && is_vector_dot_operation;

  assign out.datapath_src_reg_a = decoder_out.src_reg_a;

  assign out.datapath_src_reg_b = decoder_out.src_reg_b;

  assign out.datapath_dst_reg = decoder_out.dst_reg;

  assign out.gpu_command =
      fsm_out_state == `FSM_EXECUTE ? decoder_out.gpu_command : gpu_types::GPU_COMMAND_NONE;

  // GLAUNCH carries the warp's first instruction address in its addr11 field.
  // Keep the address meaningful only alongside the one-cycle launch command.
  assign out.gpu_launch_address =
      fsm_out_state == `FSM_EXECUTE && decoder_out.opcode == `OP_GLAUNCH ?
          decoder_out.address : 16'b0;

  assign out.cmp_less_flag = cmp_less_flag;

  assign out.halted = fsm_out_state == `FSM_HALT;

  assign out.datapath_writeback_source = control_helpers_pkg::writeback_source_for_opcode(
      decoder_out.opcode
  );

  assign out.alu_op = decoder_out.opcode[3:0];

endmodule
