`include "isa.vh"
`include "fsm_states.vh"
`include "cpu.v"

module cpu_tb;
  reg         clk;
  reg         reset;
  reg  [15:0] mem_read_data;
  wire [ 8:0] mem_address;
  wire [15:0] mem_write_data;
  wire        mem_write_enable;
  wire        halted;

  cpu dut (
      .clk             (clk),
      .reset           (reset),
      .mem_read_data   (mem_read_data),
      .mem_address     (mem_address),
      .mem_write_data  (mem_write_data),
      .mem_write_enable(mem_write_enable),
      .halted          (halted)
  );

  task test_case(input [7:0] test_number, input tc_reset, input [15:0] tc_instruction,
                 input [15:0] tc_load_data, input [2:0] tc_evaluation_state,
                 input expected_mem_write_enable, input [8:0] expected_mem_address,
                 input [15:0] expected_mem_write_data, input expected_halted);
    integer clocks_waited;
    integer cleanup_clocks;
    begin
      mem_read_data = tc_instruction;
      reset = tc_reset;

      // FETCH/DECODE
      clk = 0;
      #10;
      clk = 1;
      #10;

      // EXECUTE
      clk = 0;
      #10;
      clk = 1;
      #10;

      // Wait until this instruction is decoded and the requested evaluation state is active.
      clocks_waited = 0;
      while ((dut.control_unit_module.fsm_out_state !== tc_evaluation_state ||
              dut.control_unit_module.decoder_out_opcode !== tc_instruction[15:12]) &&
             clocks_waited < 4) begin
        clk = 0;
        #10;
        clk = 1;
        #10;
        clocks_waited = clocks_waited + 1;
      end

      if (dut.control_unit_module.fsm_out_state !== tc_evaluation_state ||
          dut.control_unit_module.decoder_out_opcode !== tc_instruction[15:12]) begin
        $fatal(1, "Test case #%d did not reach evaluation state %d for instruction %h",
               test_number, tc_evaluation_state, tc_instruction);
      end

      // Present a RAM response during LOAD's memory state before evaluating it.
      if (tc_instruction[15:12] == `OP_LOAD && tc_evaluation_state == `FSM_MEMORY) begin
        clk = 0;
        mem_read_data = tc_load_data;
        #10;
      end

      if (mem_write_enable !== expected_mem_write_enable ||
          halted !== expected_halted ||
          ((tc_instruction[15:12] == `OP_LOAD || tc_instruction[15:12] == `OP_STORE) &&
           mem_address !== expected_mem_address) ||
          (expected_mem_write_enable && mem_write_data !== expected_mem_write_data)) begin
        $fatal(
            1,
            "Test case #%d failed - instruction: %h | write_enable: %d, address: %d, write_data: %d, halted: %d | expected write_enable: %d, address: %d, write_data: %d, halted: %d",
            test_number, tc_instruction, mem_write_enable, mem_address, mem_write_data, halted,
            expected_mem_write_enable, expected_mem_address, expected_mem_write_data,
            expected_halted);
      end

      // Finish LOAD/STORE so the next sequential test starts from FETCH/DECODE.
      cleanup_clocks = 0;
      while ((tc_instruction[15:12] == `OP_LOAD || tc_instruction[15:12] == `OP_STORE) &&
             dut.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE && cleanup_clocks < 2) begin
        if (clk !== 1'b0) begin
          clk = 0;
          #10;
        end
        if (tc_instruction[15:12] == `OP_LOAD &&
            dut.control_unit_module.fsm_out_state == `FSM_MEMORY) begin
          mem_read_data = tc_load_data;
        end
        clk = 1;
        #10;
        cleanup_clocks = cleanup_clocks + 1;
      end
    end
  endtask

  task test_jump_equal(input [7:0] test_number, input [8:0] tc_address,
                       input tc_expected_taken);
    reg [8:0] pc_before;
    reg [8:0] expected_pc;
    begin
      if (dut.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE)
        $fatal(1, "Test case #%d began JE outside of FETCH/DECODE", test_number);

      if (dut.control_unit_module.cmp_equal_flag !== tc_expected_taken)
        $fatal(1, "Test case #%d has cmp_equal_flag=%b, expected %b", test_number,
               dut.control_unit_module.cmp_equal_flag, tc_expected_taken);

      pc_before = mem_address;
      mem_read_data = {`OP_JE, 3'b000, tc_address};
      reset = 1'b0;

      // FETCH/DECODE JE, then execute it and observe the next fetch address.
      clk = 0;
      #10;
      clk = 1;
      #10;
      clk = 0;
      #10;
      clk = 1;
      #10;

      expected_pc = tc_expected_taken ? tc_address : pc_before + 9'd1;
      if (dut.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE ||
          dut.control_unit_module.decoder_out_opcode !== `OP_JE ||
          mem_address !== expected_pc) begin
        $fatal(1,
               "Test case #%d failed - JE target: %d, taken: %b, PC: %d, expected PC: %d",
               test_number, tc_address, tc_expected_taken, mem_address, expected_pc);
      end
    end
  endtask

  task test_jump(input [7:0] test_number, input [8:0] tc_address);
    begin
      if (dut.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE)
        $fatal(1, "Test case #%d began JMP outside of FETCH/DECODE", test_number);

      mem_read_data = {`OP_JMP, 3'b000, tc_address};
      reset = 1'b0;

      // FETCH/DECODE JMP, then execute it and observe the target as the next fetch address.
      clk = 0;
      #10;
      clk = 1;
      #10;
      clk = 0;
      #10;
      clk = 1;
      #10;

      if (dut.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE ||
          dut.control_unit_module.decoder_out_opcode !== `OP_JMP ||
          mem_address !== tc_address) begin
        $fatal(1, "Test case #%d failed - JMP target: %d, PC: %d", test_number,
               tc_address, mem_address);
      end
    end
  endtask

  initial begin
    // R0 is the address register for the memory-operation checks below.
    test_case(.test_number(1), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd0, 9'd100}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // LDI R1, 0x05A
    test_case(.test_number(2), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd1, 9'h05A}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // STORE R1, R0 exercises separate value and address register operands.
    test_case(.test_number(3), .tc_reset(1'b0),
              .tc_instruction({`OP_STORE, 3'd1, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h005A), .expected_halted(1'b0));

    // LOAD R2, R0 uses the same register-derived memory address.
    test_case(.test_number(4), .tc_reset(1'b0),
              .tc_instruction({`OP_LOAD, 3'd2, 3'd0, 6'b000000}),
              .tc_load_data(16'h005A), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // STORE R2, R0 proves that LOAD wrote 0x05A to R2.
    test_case(.test_number(5), .tc_reset(1'b0),
              .tc_instruction({`OP_STORE, 3'd2, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h005A), .expected_halted(1'b0));

    // ADD R3, R1, R2 verifies a dependency on the prior LDI and LOAD results.
    test_case(.test_number(6), .tc_reset(1'b0),
              .tc_instruction({`OP_ADD, 3'd3, 3'd1, 3'd2, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // STORE R3, R0 proves ADD produced 0x00B4.
    test_case(.test_number(66), .tc_reset(1'b0),
              .tc_instruction({`OP_STORE, 3'd3, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h00B4), .expected_halted(1'b0));

    // Prepare boundary operands for the remaining ALU tests.
    test_case(.test_number(7), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd3, 9'h1FF}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(8), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd4, 9'h001}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // ADD R5, R3, R4: carry through bit 8, 0x01FF + 1 = 0x0200.
    test_case(.test_number(9), .tc_reset(1'b0),
              .tc_instruction({`OP_ADD, 3'd5, 3'd3, 3'd4, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(10), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd5, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0200), .expected_halted(1'b0));

    // SUB R6, R4, R3: unsigned underflow, 1 - 0x01FF = 0xFE02.
    test_case(.test_number(11), .tc_reset(1'b0),
              .tc_instruction({`OP_SUB, 3'd6, 3'd4, 3'd3, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(12), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd6, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'hFE02), .expected_halted(1'b0));

    // SUB R7, R4, R4: equal operands must yield zero.
    test_case(.test_number(13), .tc_reset(1'b0),
              .tc_instruction({`OP_SUB, 3'd7, 3'd4, 3'd4, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(14), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0000), .expected_halted(1'b0));

    // SUB R6, R7, R4 creates 0xFFFF; ADD R7, R6, R4 must wrap back to zero.
    test_case(.test_number(15), .tc_reset(1'b0),
              .tc_instruction({`OP_SUB, 3'd6, 3'd7, 3'd4, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(16), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd6, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'hFFFF), .expected_halted(1'b0));

    test_case(.test_number(17), .tc_reset(1'b0),
              .tc_instruction({`OP_ADD, 3'd7, 3'd6, 3'd4, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(18), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0000), .expected_halted(1'b0));

    // SHL R6, R4, R5: 1 << 15 exercises the destination sign bit.
    test_case(.test_number(19), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd5, 9'd15}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(20), .tc_reset(1'b0),
              .tc_instruction({`OP_SHL, 3'd6, 3'd4, 3'd5, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(21), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd6, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h8000), .expected_halted(1'b0));

    // SHL R7, R6, R5: 0x0100 << 8 overflows the 16-bit result to zero.
    test_case(.test_number(22), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd5, 9'd8}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(23), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd6, 9'h100}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(24), .tc_reset(1'b0),
              .tc_instruction({`OP_SHL, 3'd7, 3'd6, 3'd5, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(25), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0000), .expected_halted(1'b0));

    // SHR uses a zero-fill logical shift: 0x8000 >> 1 = 0x4000.
    test_case(.test_number(26), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd5, 9'd15}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(27), .tc_reset(1'b0),
              .tc_instruction({`OP_SHL, 3'd6, 3'd4, 3'd5, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(28), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd5, 9'd1}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(29), .tc_reset(1'b0),
              .tc_instruction({`OP_SHR, 3'd7, 3'd6, 3'd5, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(30), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h4000), .expected_halted(1'b0));

    // A shift count at least as wide as the word shifts every bit out.
    test_case(.test_number(31), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd5, 9'd16}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(32), .tc_reset(1'b0),
              .tc_instruction({`OP_SHR, 3'd7, 3'd3, 3'd5, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(33), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0000), .expected_halted(1'b0));

    // MUL R7, R1, R2 verifies a dependency on the values produced by LDI and LOAD.
    test_case(.test_number(34), .tc_reset(1'b0),
              .tc_instruction({`OP_MUL, 3'd7, 3'd1, 3'd2, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(35), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h1FA4), .expected_halted(1'b0));

    // MUL R7, R3, R7 checks a destination/source alias and truncates 0x01FF * 0x0100 to 0xFF00.
    test_case(.test_number(36), .tc_reset(1'b0), .tc_instruction({`OP_LDI, 3'd7, 9'h100}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(37), .tc_reset(1'b0),
              .tc_instruction({`OP_MUL, 3'd7, 3'd3, 3'd7, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(38), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'hFF00), .expected_halted(1'b0));

    // OR R5, R6, R4 builds 0x8001 from disjoint high and low bits.
    test_case(.test_number(39), .tc_reset(1'b0),
              .tc_instruction({`OP_OR, 3'd5, 3'd6, 3'd4, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(40), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd5, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h8001), .expected_halted(1'b0));

    // AND R7, R5, R3 retains only their shared low bit.
    test_case(.test_number(41), .tc_reset(1'b0),
              .tc_instruction({`OP_AND, 3'd7, 3'd5, 3'd3, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(42), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0001), .expected_halted(1'b0));

    // AND R7, R6, R3 has no common set bits and must yield zero.
    test_case(.test_number(43), .tc_reset(1'b0),
              .tc_instruction({`OP_AND, 3'd7, 3'd6, 3'd3, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(44), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0000), .expected_halted(1'b0));

    // OR R5, R6, R3 combines the high bit with every bit in 0x01FF.
    test_case(.test_number(45), .tc_reset(1'b0),
              .tc_instruction({`OP_OR, 3'd5, 3'd6, 3'd3, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(46), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd5, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h81FF), .expected_halted(1'b0));

    // XOR R7, R5, R3 removes the common low bits and leaves the high bit.
    test_case(.test_number(47), .tc_reset(1'b0),
              .tc_instruction({`OP_XOR, 3'd7, 3'd5, 3'd3, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(48), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h8000), .expected_halted(1'b0));

    // XOR of a value with itself must be zero.
    test_case(.test_number(49), .tc_reset(1'b0),
              .tc_instruction({`OP_XOR, 3'd7, 3'd3, 3'd3, 3'b000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(50), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h0000), .expected_halted(1'b0));

    // MOV R7, R5 verifies that MOV writes source operand A through the ALU path.
    test_case(.test_number(51), .tc_reset(1'b0),
              .tc_instruction({`OP_MOV, 3'd7, 3'd5, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_case(.test_number(52), .tc_reset(1'b0), .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h81FF), .expected_halted(1'b0));

    // Memory addresses are the low nine bits of the address register.
    test_case(.test_number(67), .tc_reset(1'b0),
              .tc_instruction({`OP_MOV, 3'd0, 3'd5, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // R0 is now 0x81FF, whose low nine bits select memory address 0x1FF.
    test_case(.test_number(68), .tc_reset(1'b0),
              .tc_instruction({`OP_STORE, 3'd7, 3'd0, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_MEMORY),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'h1FF),
              .expected_mem_write_data(16'h81FF), .expected_halted(1'b0));

    // CMP and JE are control-unit operations: equality is latched by CMP and consumed by JE.
    test_case(.test_number(53), .tc_reset(1'b0),
              .tc_instruction({`OP_CMP, 3'd1, 3'd2, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // R1 and R2 are both 0x005A, so JE must load its target into the PC.
    test_jump_equal(.test_number(54), .tc_address(9'd200), .tc_expected_taken(1'b1));

    test_case(.test_number(55), .tc_reset(1'b0),
              .tc_instruction({`OP_CMP, 3'd1, 3'd3, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // R1 (0x005A) and R3 (0x01FF) differ, so JE must advance normally instead of branching.
    test_jump_equal(.test_number(56), .tc_address(9'd300), .tc_expected_taken(1'b0));

    // R5 and R7 both contain 0x81FF after MOV; JE must support a zero target.
    test_case(.test_number(57), .tc_reset(1'b0),
              .tc_instruction({`OP_CMP, 3'd5, 3'd7, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_jump_equal(.test_number(58), .tc_address(9'd0), .tc_expected_taken(1'b1));

    // R5 (0x81FF) and R6 (0x8000) differ, so leave the flag clear for the next JMP/JE pair.
    test_case(.test_number(59), .tc_reset(1'b0),
              .tc_instruction({`OP_CMP, 3'd5, 3'd6, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // JMP is unconditional, even with a clear comparison flag.
    test_jump(.test_number(60), .tc_address(9'd511));

    // A not-taken JE at address 511 must increment and wrap the 9-bit PC to zero.
    test_jump_equal(.test_number(61), .tc_address(9'd0), .tc_expected_taken(1'b0));

    // Self-comparison sets the flag again; JMP must remain unconditional when it is set.
    test_case(.test_number(62), .tc_reset(1'b0),
              .tc_instruction({`OP_CMP, 3'd3, 3'd3, 6'b000000}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_FETCH_DECODE),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    test_jump(.test_number(63), .tc_address(9'd256));

    // A taken JE must support the maximum representable 9-bit target.
    test_jump_equal(.test_number(64), .tc_address(9'd511), .tc_expected_taken(1'b1));

    test_case(.test_number(65), .tc_reset(1'b0), .tc_instruction({`OP_HALT_OR_VECTOR, 12'b0}),
              .tc_load_data(16'b0), .tc_evaluation_state(`FSM_HALT_OR_VECTOR),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b1));

    $finish;
  end

endmodule
