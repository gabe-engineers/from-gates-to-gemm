`include "gpu_types.svh"
`include "warp_decoder.sv"
`include "fsm_states.svh"
`include "control_helpers.svh"

module warp_control_unit (
    input clk,
    input reset,
    input [15:0] start_address,
    input enable,
    input [15:0] mem_read_data,
    output wire halted,
    output wire [15:0] instruction_address,
    output wire gpu_types::lane_request_t out
);

  wire [2:0] fsm_out_state;
  wire gpu_types::warp_decoder_out_t decoder_out;
  wire [15:0] ir;
  logic [15:0] pc;

  // A launch resets the warp state and installs the supplied first instruction
  // address. Warp control flow is not implemented, so supported instructions
  // advance this PC sequentially when they execute.
  always @(posedge clk) begin
    if (reset) pc <= start_address;
    else if (enable && fsm_out_state == `FSM_EXECUTE) pc <= pc + 16'd1;
  end

  assign instruction_address = pc;

  assign out.alu_op = decoder_out.opcode[3:0];
  assign out.writeback_source =
      control_helpers_pkg::writeback_source_for_opcode(decoder_out.opcode);

  assign out.write_enable =
      enable && decoder_out.valid && fsm_out_state == `FSM_EXECUTE &&
      control_helpers_pkg::is_execute_register_write_op(decoder_out.opcode);

  assign out.dst_reg = decoder_out.dst_reg;
  assign out.src_reg_a = decoder_out.src_reg_a;
  assign out.src_reg_b = decoder_out.src_reg_b;
  assign out.immediate = decoder_out.immediate;
  assign out.jmp_address = 16'b0;

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
      .instruction_valid(decoder_out.valid),
      .memory_complete(1'b1),
      .gpu_busy       (1'b0),
      .state          (fsm_out_state)
  );

  assign halted = fsm_out_state == `FSM_HALT;

endmodule
