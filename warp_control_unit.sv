`include "gpu_types.svh"
`include "warp_decoder.sv"
`include "fsm_states.svh"
`include "control_helpers.svh"

module warp_control_unit (
    input clk,
    input reset,
    input [15:0] start_address,
    input enable,
    input gpu_types::warp_lane_status_t lane_status,
    input [15:0] mem_read_data,
    output wire gpu_types::warp_control_unit_out_t out
);

  wire [2:0] fsm_out_state;
  wire gpu_types::warp_decoder_out_t decoder_out;
  wire [15:0] ir;
  logic [15:0] pc;
  logic cmp_equal_flag;

  wire is_cmp = decoder_out.opcode == `OP_CMP;
  wire is_jmp = decoder_out.opcode == `OP_JMP;
  wire is_je = decoder_out.opcode == `OP_JE;
  wire is_load = decoder_out.opcode == `OP_LOAD;
  wire is_store = decoder_out.opcode == `OP_STORE;

  wire branch_diverged = is_cmp && lane_status.diverged;
  wire branch_taken = is_jmp || (is_je && cmp_equal_flag);
  wire mem_phase = fsm_out_state == `FSM_MEMORY;

  always @(posedge clk) begin
    if (reset) pc <= start_address;
    else if (enable && fsm_out_state == `FSM_EXECUTE) begin
      if (branch_taken) pc <= decoder_out.address;
      else pc <= pc + 16'd1;
    end
  end

  always @(posedge clk) begin
    if (reset) cmp_equal_flag <= 1'b0;
    else if (enable && fsm_out_state == `FSM_EXECUTE && is_cmp && !branch_diverged)
      cmp_equal_flag <= lane_status.operands_equal;
  end

  assign out.instruction_address = pc;

  assign out.warp_request.alu_op = decoder_out.opcode[3:0];
  assign out.warp_request.writeback_source =
      is_load ? control_helpers_pkg::WB_MEMORY :
      control_helpers_pkg::writeback_source_for_opcode(decoder_out.opcode);

  assign out.warp_request.write_enable =
      (enable && decoder_out.valid && fsm_out_state == `FSM_EXECUTE &&
       control_helpers_pkg::is_execute_register_write_op(decoder_out.opcode)) ||
      (enable && mem_phase && is_load);

  assign out.mem_access = mem_phase && (is_load || is_store);
  assign out.mem_write_enable = mem_phase && is_store;

  assign out.warp_request.dst_reg = decoder_out.dst_reg;
  assign out.warp_request.src_reg_a = decoder_out.src_reg_a;
  assign out.warp_request.src_reg_b = decoder_out.src_reg_b;
  assign out.warp_request.immediate = decoder_out.immediate;
  assign out.warp_request.jmp_address = 16'b0;

  register ir_module (
      .clk         (clk),
      .reset       (reset),
      .write_enable(enable && fsm_out_state == `FSM_FETCH_DECODE),
      .data_in     (mem_read_data),
      .data_out    (ir)
  );

  warp_decoder decoder_module (
      .instruction_data(ir),
      .out             (decoder_out)
  );

  control_fsm fsm (
      .clk            (clk),
      .reset          (reset),
      .enable         (enable),
      .opcode         (decoder_out.opcode),
      .instruction_valid(decoder_out.valid && !branch_diverged),
      .memory_complete(1'b1),
      .gpu_busy       (1'b0),
      .state          (fsm_out_state)
  );

  assign out.halted = fsm_out_state == `FSM_HALT;

endmodule
