`include "control_fsm.v"

module control_fsm_tb;
  reg clk;
  reg reset;
  reg [4:0] opcode;
  reg memory_complete;
  wire [2:0] state;

  control_fsm dut (clk, reset, opcode, memory_complete, state);
  always #5 clk = ~clk;

  task execute_single_cycle(input [4:0] operation);
    begin
      opcode = operation;
      @(posedge clk); #1;
      if (state !== `FSM_EXECUTE) $fatal(1, "opcode %h did not enter EXECUTE", operation);
      @(posedge clk); #1;
      if (state !== `FSM_FETCH_DECODE) $fatal(1, "opcode %h did not complete", operation);
    end
  endtask

  task execute_memory(input [4:0] operation);
    begin
      opcode = operation;
      memory_complete = 1'b0;
      @(posedge clk); #1;
      if (state !== `FSM_EXECUTE) $fatal(1, "memory opcode did not enter EXECUTE");
      @(posedge clk); #1;
      if (state !== `FSM_MEMORY) $fatal(1, "memory opcode did not enter MEMORY");
      @(posedge clk); #1;
      if (state !== `FSM_MEMORY) $fatal(1, "memory opcode completed early");
      memory_complete = 1'b1;
      @(posedge clk); #1;
      if (state !== `FSM_FETCH_DECODE) $fatal(1, "memory opcode did not complete");
    end
  endtask

  initial begin
    clk = 0;
    reset = 0;
    opcode = `OP_LDI;
    memory_complete = 1;

    execute_single_cycle(`OP_LDI);
    execute_single_cycle(`OP_ADD);
    execute_single_cycle(`OP_CMP);
    execute_single_cycle(`OP_JMP);
    execute_single_cycle(`OP_VADD);
    execute_single_cycle(`OP_VDOT);
    execute_memory(`OP_LOAD);
    execute_memory(`OP_STORE);
    execute_memory(`OP_VLD);
    execute_memory(`OP_VST);

    opcode = `OP_HALT;
    @(posedge clk); #1;
    if (state !== `FSM_EXECUTE) $fatal(1, "HALT did not enter EXECUTE");
    @(posedge clk); #1;
    if (state !== `FSM_HALT) $fatal(1, "HALT did not stop");
    opcode = `OP_ADD;
    @(posedge clk); #1;
    if (state !== `FSM_HALT) $fatal(1, "halted FSM advanced without reset");
    reset = 1;
    @(posedge clk); #1;
    if (state !== `FSM_FETCH_DECODE) $fatal(1, "reset did not leave HALT");

    // Unsupported/deferred opcodes stop without executing side effects.
    reset = 0;
    opcode = 5'h16;
    @(posedge clk); #1;
    @(posedge clk); #1;
    if (state !== `FSM_HALT) $fatal(1, "unsupported opcode did not stop");

    $display("control_fsm_tb passed");
    $finish;
  end
endmodule
