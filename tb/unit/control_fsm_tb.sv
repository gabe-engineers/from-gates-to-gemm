`include "control_fsm.sv"

module control_fsm_tb;
  logic clk;
  logic reset;
  logic enable;
  logic [4:0] opcode;
  logic instruction_valid;
  logic memory_complete;
  logic gpu_busy;
  wire [2:0] state;

  control_fsm dut (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .opcode(opcode),
      .instruction_valid(instruction_valid),
      .memory_complete(memory_complete),
      .gpu_busy(gpu_busy),
      .state(state)
  );
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
    enable = 1;
    opcode = `OP_LDI;
    instruction_valid = 1;
    memory_complete = 1;
    gpu_busy = 0;

    execute_single_cycle(`OP_LDI);
    execute_single_cycle(`OP_LUI);
    execute_single_cycle(`OP_TID);
    execute_single_cycle(`OP_ADD);
    execute_single_cycle(`OP_CMP);
    execute_single_cycle(`OP_JMP);
    execute_single_cycle(`OP_VADD);
    execute_single_cycle(`OP_VDOT);
    execute_single_cycle(`OP_GLAUNCH);
    execute_single_cycle(`OP_GWAIT);
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

    // GWAIT remains in its dedicated state until the GPU reports idle.
    reset = 0;
    gpu_busy = 1;
    opcode = `OP_GWAIT;
    @(posedge clk); #1;
    if (state !== `FSM_EXECUTE) $fatal(1, "GWAIT did not enter EXECUTE");
    @(posedge clk); #1;
    if (state !== `FSM_GPU_WAIT) $fatal(1, "GWAIT did not enter GPU_WAIT");
    @(posedge clk); #1;
    if (state !== `FSM_GPU_WAIT) $fatal(1, "GWAIT completed while GPU was busy");
    gpu_busy = 0;
    @(posedge clk); #1;
    if (state !== `FSM_FETCH_DECODE) $fatal(1, "GWAIT did not resume when GPU became idle");

    // A decoder can halt a processor before an otherwise recognizable opcode
    // reaches its datapath.
    instruction_valid = 0;
    opcode = `OP_ADD;
    @(posedge clk); #1;
    if (state !== `FSM_EXECUTE) $fatal(1, "invalid instruction did not enter EXECUTE");
    @(posedge clk); #1;
    if (state !== `FSM_HALT) $fatal(1, "invalid instruction did not halt");
    reset = 1;
    @(posedge clk); #1;
    if (state !== `FSM_FETCH_DECODE) $fatal(1, "reset did not recover from invalid instruction");
    reset = 0;
    instruction_valid = 1;

    // Unsupported/deferred opcodes stop without executing side effects.
    reset = 0;
    opcode = 5'h1B;
    @(posedge clk); #1;
    @(posedge clk); #1;
    if (state !== `FSM_HALT) $fatal(1, "unsupported opcode did not stop");

    $display("control_fsm_tb passed");
    $finish;
  end
endmodule
