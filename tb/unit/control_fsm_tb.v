`include "control_fsm.v"

module control_fsm_tb;
  reg        clk;
  reg        reset;
  reg  [3:0] opcode;
  reg        memory_complete;
  reg  [2:0] halt_or_vector_subop;
  wire [2:0] state;

  control_fsm dut (
    .clk            (clk),
    .reset          (reset),
    .opcode         (opcode),
    .memory_complete(memory_complete),
    .halt_or_vector_subop(halt_or_vector_subop),
    .state          (state)
  );

  task test_case(input [7:0] test_number, input tc_reset, input [3:0] tc_opcode,
                 input [2:0] expected_state);
    begin
      reset  = tc_reset;
      opcode = tc_opcode;
      memory_complete = 1'b1;
      halt_or_vector_subop = `HALT_OR_VECTOR_SUBOP_HALT;
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

    test_case(.test_number(33), .tc_reset(0), .tc_opcode(`OP_HALT_OR_VECTOR), .expected_state(`FSM_EXECUTE));
    test_case(.test_number(34), .tc_reset(0), .tc_opcode(`OP_HALT_OR_VECTOR), .expected_state(`FSM_HALT_OR_VECTOR));
    test_case(.test_number(35), .tc_reset(0), .tc_opcode(`OP_ADD), .expected_state(`FSM_HALT_OR_VECTOR));
    test_case(.test_number(36), .tc_reset(1), .tc_opcode(`OP_ADD), .expected_state(`FSM_FETCH_DECODE));

    // A vector memory transfer holds the FSM in MEMORY until the final lane completes.
    reset = 1'b0;
    opcode = `OP_LOAD;
    memory_complete = 1'b1;
    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    if (state !== `FSM_MEMORY)
      $fatal(1, "LOAD did not enter the MEMORY state");

    memory_complete = 1'b0;
    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    if (state !== `FSM_MEMORY)
      $fatal(1, "FSM left MEMORY before the vector transfer completed");

    memory_complete = 1'b1;
    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    if (state !== `FSM_FETCH_DECODE)
      $fatal(1, "FSM did not leave MEMORY after the vector transfer completed");

    // A supported vector ALU sub-op executes and returns to fetch instead of halting.
    reset = 1'b0;
    opcode = `OP_HALT_OR_VECTOR;
    memory_complete = 1'b1;
    halt_or_vector_subop = `HALT_OR_VECTOR_SUBOP_VADD;
    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    if (state !== `FSM_EXECUTE)
      $fatal(1, "VADD did not enter EXECUTE");

    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    if (state !== `FSM_FETCH_DECODE)
      $fatal(1, "VADD did not return to FETCH/DECODE");

    halt_or_vector_subop = `HALT_OR_VECTOR_SUBOP_VDOT;
    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    if (state !== `FSM_EXECUTE)
      $fatal(1, "VDOT did not enter EXECUTE");

    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
    if (state !== `FSM_FETCH_DECODE)
      $fatal(1, "VDOT did not return to FETCH/DECODE");

    $finish;
  end

endmodule
