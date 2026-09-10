`include "control_fsm.v"

module control_fsm_tb;
  reg        clk;
  reg        reset;
  reg  [3:0] opcode;
  wire [2:0] state;

  control_fsm dut (
    clk,
    reset,
    opcode,
    state
  );

  task test_case(input [7:0] test_number, input tc_reset, input [3:0] tc_opcode,
                 input [2:0] expected_state);
    begin
      reset  = tc_reset;
      opcode = tc_opcode;
      clk    = 0;
      #10;
      clk = 1;
      #10;

      if (state != expected_state) begin
        $display("Test case #%d failed - reset: %d, opcode: %d | state: %d, expected state: %d",
                 test_number, reset, opcode, state, expected_state);
      end
    end
  endtask

  initial begin
    test_case(.test_number(1), .tc_reset(0), .tc_opcode(`OP_LDI), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(2), .tc_reset(0), .tc_opcode(`OP_LDI), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(3), .tc_reset(0), .tc_opcode(`OP_MOV), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(4), .tc_reset(0), .tc_opcode(`OP_MOV), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(5), .tc_reset(0), .tc_opcode(`OP_ADD), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(6), .tc_reset(0), .tc_opcode(`OP_ADD), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(7), .tc_reset(0), .tc_opcode(`OP_SUB), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(8), .tc_reset(0), .tc_opcode(`OP_SUB), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(9), .tc_reset(0), .tc_opcode(`OP_AND), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(10), .tc_reset(0), .tc_opcode(`OP_AND), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(11), .tc_reset(0), .tc_opcode(`OP_OR), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(12), .tc_reset(0), .tc_opcode(`OP_OR), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(13), .tc_reset(0), .tc_opcode(`OP_XOR), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(14), .tc_reset(0), .tc_opcode(`OP_XOR), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(15), .tc_reset(0), .tc_opcode(`OP_SHL), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(16), .tc_reset(0), .tc_opcode(`OP_SHL), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(17), .tc_reset(0), .tc_opcode(`OP_SHR), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(18), .tc_reset(0), .tc_opcode(`OP_SHR), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(19), .tc_reset(0), .tc_opcode(`OP_MUL), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(20), .tc_reset(0), .tc_opcode(`OP_MUL), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(21), .tc_reset(0), .tc_opcode(`OP_CMP), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(22), .tc_reset(0), .tc_opcode(`OP_CMP), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(23), .tc_reset(0), .tc_opcode(`OP_JMP), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(24), .tc_reset(0), .tc_opcode(`OP_JMP), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(25), .tc_reset(0), .tc_opcode(`OP_JE), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(26), .tc_reset(0), .tc_opcode(`OP_JE), .expected_state(`FSM_FETCH_DECODE));

    test_case(.test_number(27), .tc_reset(0), .tc_opcode(`OP_LOAD), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(28), .tc_reset(0), .tc_opcode(`OP_LOAD), .expected_state(`FSM_MEMORY));
    test_case(.test_number(29), .tc_reset(0), .tc_opcode(`OP_LOAD), .expected_state(`FSM_FETCH_DECODE));
    test_case(.test_number(30), .tc_reset(0), .tc_opcode(`OP_STORE), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(31), .tc_reset(0), .tc_opcode(`OP_STORE), .expected_state(`FSM_MEMORY));
    test_case(.test_number(32), .tc_reset(0), .tc_opcode(`OP_STORE), .expected_state(`FSM_FETCH_DECODE));

    test_case(.test_number(33), .tc_reset(0), .tc_opcode(`OP_HALT), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(34), .tc_reset(0), .tc_opcode(`OP_HALT), .expected_state(`FSM_HALT));
    test_case(.test_number(35), .tc_reset(0), .tc_opcode(`OP_ADD), .expected_state(`FSM_HALT));
    test_case(.test_number(36), .tc_reset(1), .tc_opcode(`OP_ADD), .expected_state(`FSM_FETCH_DECODE));

    $finish;
  end

endmodule
