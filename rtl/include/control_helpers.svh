`ifndef CONTROL_HELPERS_SVH
`define CONTROL_HELPERS_SVH

`include "isa.svh"

package control_helpers_pkg;

  // Writeback constants
  localparam logic [1:0] WB_ALU = 2'b00;
  localparam logic [1:0] WB_IMMEDIATE = 2'b01;
  localparam logic [1:0] WB_THREAD_ID = 2'b10;

  function automatic logic is_execute_register_write_op(input logic [4:0] opcode);
    begin
      case (opcode)
        `OP_LDI, `OP_LUI, `OP_MOV, `OP_ADD, `OP_SUB, `OP_SHL, `OP_SHR,
        `OP_MUL, `OP_AND, `OP_OR, `OP_XOR, `OP_TID:
        is_execute_register_write_op = 1'b1;
        default: is_execute_register_write_op = 1'b0;
      endcase
    end
  endfunction

  function automatic logic is_immediate_writeback_op(input logic [4:0] opcode);
    begin
      is_immediate_writeback_op = opcode == `OP_LOAD || opcode == `OP_LDI || opcode == `OP_LUI;
    end
  endfunction

  function automatic [1:0] writeback_source_for_opcode(input logic [4:0] opcode);
    begin
      if (opcode == `OP_TID) writeback_source_for_opcode = WB_THREAD_ID;
      else if (is_immediate_writeback_op(opcode)) writeback_source_for_opcode = WB_IMMEDIATE;
      else writeback_source_for_opcode = WB_ALU;
    end
  endfunction

endpackage

`endif
