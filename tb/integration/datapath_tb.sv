`include "datapath.sv"
`include "tb_regs.svh"

module datapath_16bit_tb;
  logic         clk;
  logic         reset;
  logic         write_enable;
  logic [ 1:0]  writeback_source;
  logic [ 2:0]  thread_id;
  logic  [ 3:0] alu_op;
  logic  [15:0] immediate;
  logic  [ 2:0] read_addr_a;
  logic  [ 2:0] read_addr_b;
  logic  [ 2:0] write_addr;
  wire [15:0] write_reg_data;

  localparam logic [1:0] WRITEBACK_SOURCE_ALU = control_helpers_pkg::WB_ALU;
  localparam logic [1:0] WRITEBACK_SOURCE_IMMEDIATE = control_helpers_pkg::WB_IMMEDIATE;
  localparam logic [1:0] WRITEBACK_SOURCE_THREAD_ID = control_helpers_pkg::WB_THREAD_ID;

  datapath_16bit dut (
      .clk             (clk),
      .reset           (reset),
      .write_enable    (write_enable),
      .writeback_source(writeback_source),
      .thread_id       (thread_id),
      .alu_op          (alu_op),
      .immediate       (immediate),
      .read_addr_a     (read_addr_a),
      .read_addr_b     (read_addr_b),
      .write_addr      (write_addr),
      .write_reg_data  (write_reg_data),
      .vector_dot_writeback_select(1'b0)
  );

  task test_case(input [15:0] test_number, input tc_reset, input tc_write_enable,
                 input [1:0] tc_writeback_source, input [3:0] tc_alu_op, input [15:0] tc_immediate,
                 input [2:0] tc_read_addr_a, input [2:0] tc_read_addr_b, input [2:0] tc_write_addr,
                 input [15:0] expected_write_reg_data);
    begin

      reset            = tc_reset;
      write_enable     = tc_write_enable;
      writeback_source = tc_writeback_source;
      alu_op           = tc_alu_op;
      immediate        = tc_immediate;
      read_addr_a      = tc_read_addr_a;
      read_addr_b      = tc_read_addr_b;
      write_addr       = tc_write_addr;

      clk = 0;
      #10;
      clk = 1;
      #10;

      if (write_reg_data !== expected_write_reg_data)
        $display(
            "FAILED Test #%d - reset: %d, write_enable: %d, writeback_source: %d, alu_op: %d, immediate: %d, read_addr_a: %d, read_addr_b: %d, write_addr: %d | write_reg_data: %d, expected_write_reg_data: %d"
                ,
            test_number,
            reset,
            write_enable,
            writeback_source,
            alu_op,
            immediate,
            read_addr_a,
            read_addr_b,
            write_addr,
            write_reg_data,
            expected_write_reg_data
        );
    end

  endtask


  initial begin
    thread_id = 3'd0;
    // ------------------------------------------------------------
    // Reset first so this section starts from known state
    // ------------------------------------------------------------
    test_case(.test_number(0), .tc_reset(1), .tc_write_enable(0),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_1), .tc_read_addr_b(`REG_2),
              .tc_write_addr(`REG_1), .expected_write_reg_data(16'd0));


    // ------------------------------------------------------------
    // Load two different registers with immediates
    // r2 = 12
    // ------------------------------------------------------------
    test_case(.test_number(1), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_IMMEDIATE),
              .tc_alu_op(`ALU_OP_ADD),  // don't care
              .tc_immediate(16'd12), .tc_read_addr_a(`REG_1),  // don't care
              .tc_read_addr_b(`REG_1),  // don't care
              .tc_write_addr(`REG_2), .expected_write_reg_data(16'd12));

    // r3 = 7
    test_case(.test_number(2), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_IMMEDIATE), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd7), .tc_read_addr_a(`REG_1), .tc_read_addr_b(`REG_1),
              .tc_write_addr(`REG_3), .expected_write_reg_data(16'd7));


    // ------------------------------------------------------------
    // r4 = r2 + r3 = 19
    // ------------------------------------------------------------
    test_case(.test_number(3), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_2), .tc_read_addr_b(`REG_3),
              .tc_write_addr(`REG_4), .expected_write_reg_data(16'd19));


    // ------------------------------------------------------------
    // Prove that r4 really got written:
    // r5 = r4 - r3 = 12
    // ------------------------------------------------------------
    test_case(.test_number(4), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_SUB),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_4), .tc_read_addr_b(`REG_3),
              .tc_write_addr(`REG_5), .expected_write_reg_data(16'd12));


    // ------------------------------------------------------------
    // Underflow:
    // r6 = r3 - r2 = 7 - 12 = -5 = 65531 in 16 bits
    // ------------------------------------------------------------
    test_case(.test_number(5), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_SUB),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_3), .tc_read_addr_b(`REG_2),
              .tc_write_addr(`REG_6), .expected_write_reg_data(16'd65531));


    // ------------------------------------------------------------
    // Bitwise operation:
    // r7 = 12 XOR 7 = 11
    // ------------------------------------------------------------
    test_case(.test_number(6), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_XOR),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_2), .tc_read_addr_b(`REG_3),
              .tc_write_addr(`REG_7), .expected_write_reg_data(16'd11));


    // ------------------------------------------------------------
    // write_enable = 0.
    // ALU computes 19, but r8 must NOT receive it, so write_reg_data remains zero.
    // ------------------------------------------------------------
    test_case(.test_number(7), .tc_reset(0), .tc_write_enable(0),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_2), .tc_read_addr_b(`REG_3),
              .tc_write_addr(`REG_8), .expected_write_reg_data(16'd0));


    // ------------------------------------------------------------
    // Now use r8. Since previous write was disabled,
    // r8 should still be zero.
    // r1 = r8 + r8 = 0
    // ------------------------------------------------------------
    test_case(.test_number(8), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_8), .tc_read_addr_b(`REG_8),
              .tc_write_addr(`REG_1), .expected_write_reg_data(16'd0));


    // ------------------------------------------------------------
    // Overwrite an existing register:
    // r2 = 200
    // ------------------------------------------------------------
    test_case(.test_number(9), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_IMMEDIATE), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd200), .tc_read_addr_a(`REG_1), .tc_read_addr_b(`REG_1),
              .tc_write_addr(`REG_2), .expected_write_reg_data(16'd200));


    // ------------------------------------------------------------
    // Verify overwrite:
    // r1 = r2 + r3 = 200 + 7 = 207
    // ------------------------------------------------------------
    test_case(.test_number(10), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_2), .tc_read_addr_b(`REG_3),
              .tc_write_addr(`REG_1), .expected_write_reg_data(16'd207));

    // The third writeback source zero-extends the local thread ID into r8.
    thread_id = 3'd5;
    test_case(.test_number(11), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_source(WRITEBACK_SOURCE_THREAD_ID), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(`REG_1), .tc_read_addr_b(`REG_1),
              .tc_write_addr(`REG_8), .expected_write_reg_data(16'd5));

    $display("Tests finished");
    $finish;

  end

endmodule
