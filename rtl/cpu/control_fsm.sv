`include "fsm_states.vh"
`include "isa.vh"

module control_fsm (
  input clk,
  input reset,
  input [4:0] opcode,
  input memory_complete,
  output logic [2:0] state
);

  initial state = `FSM_FETCH_DECODE;

  always @(posedge clk) begin
    if (reset)
      state <= `FSM_FETCH_DECODE;
    else case (state)
      `FSM_FETCH_DECODE:
        state           <= `FSM_EXECUTE;
      `FSM_EXECUTE: begin
        case (opcode)
          `OP_LDI, `OP_LUI, `OP_MOV, `OP_ADD, `OP_SUB, `OP_AND, `OP_OR, `OP_XOR,
          `OP_SHL, `OP_SHR, `OP_MUL, `OP_CMP, `OP_JMP, `OP_JE,
          `OP_VADD, `OP_VSUB, `OP_VMUL, `OP_VDOT:
            state <= `FSM_FETCH_DECODE;
          `OP_LOAD, `OP_STORE, `OP_VLD, `OP_VST:
            state <= `FSM_MEMORY;
          `OP_HALT:
            state <= `FSM_HALT;
          // Deferred and reserved opcodes have no side effects and stop the
          // processor instead of leaving it wedged in EXECUTE.
          default:
            state <= `FSM_HALT;
        endcase
      end
      `FSM_MEMORY: begin
        if (memory_complete) state <= `FSM_FETCH_DECODE;
      end
      `FSM_HALT: state <= `FSM_HALT;
    endcase
  end
endmodule
