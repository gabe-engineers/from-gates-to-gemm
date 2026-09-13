`include "fsm_states.vh"
`include "isa.vh"

module control_fsm (
  input clk,
  input reset,
  input [3:0] opcode,
  input memory_complete,
  input [2:0] halt_or_vector_subop,
  output reg [2:0] state
);

  initial state = `FSM_FETCH_DECODE;

  always @(posedge clk) begin
    case (state)
      `FSM_FETCH_DECODE:
        state           <= `FSM_EXECUTE;
      `FSM_EXECUTE: begin
        case (opcode)
          `OP_LDI, `OP_MOV,`OP_ADD, `OP_SUB, `OP_AND, `OP_OR, `OP_XOR, `OP_SHL, `OP_SHR, `OP_MUL, `OP_CMP, `OP_JMP, `OP_JE : state <= `FSM_FETCH_DECODE;
          `OP_LOAD, `OP_STORE: state <= `FSM_MEMORY;
          `OP_HALT_OR_VECTOR: begin
            case (halt_or_vector_subop)
              `HALT_OR_VECTOR_SUBOP_VADD,
              `HALT_OR_VECTOR_SUBOP_VSUB,
              `HALT_OR_VECTOR_SUBOP_VMUL,
              `HALT_OR_VECTOR_SUBOP_VDOT: state <= `FSM_FETCH_DECODE;
              default: state <= `FSM_HALT_OR_VECTOR;
            endcase
          end
        endcase
      end
      `FSM_MEMORY: begin
        if (memory_complete) state <= `FSM_FETCH_DECODE;
      end
      `FSM_HALT_OR_VECTOR: begin
        if (reset) begin
          state <= `FSM_FETCH_DECODE;
        end
      end
    endcase
  end
endmodule
