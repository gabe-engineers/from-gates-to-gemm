`include "decoder.sv"
`include "tb_regs.svh"

module decoder_tb;
  // Power-up value matches the CPU instruction register, which starts at zero.
  logic [15:0] instruction_data = 16'b0;
  wire cpu_types_pkg::decoder_out_t decoder_out;

  decoder dut (
      .instruction_data(instruction_data),
      .out             (decoder_out)
  );

  // Unused operand fields are left as 3'd0. Because the ISA encodes r1 as zero,
  // that literal is not given a register name to avoid implying r1.
  task test_case(input [7:0] number, input [15:0] instruction, input [4:0] expected_opcode,
                 input [2:0] expected_dst, input [2:0] expected_a, input [2:0] expected_b,
                 input [15:0] expected_immediate, input [15:0] expected_address);
    begin
      instruction_data = instruction;
      #1;
      if (decoder_out.opcode !== expected_opcode || decoder_out.dst_reg !== expected_dst ||
          decoder_out.src_reg_a !== expected_a || decoder_out.src_reg_b !== expected_b ||
          decoder_out.immediate !== expected_immediate || decoder_out.address !== expected_address)
        $fatal(1, "decoder case %0d failed for %h", number, instruction);
    end
  endtask

  initial begin
    // Let the combinational decoder settle before sampling its power-up value.
    #1;
    if (decoder_out.opcode !== `OP_LDI || decoder_out.dst_reg !== `REG_1 ||
        decoder_out.src_reg_a !== 3'd0 || decoder_out.src_reg_b !== 3'd0 ||
        decoder_out.immediate !== 16'd0 || decoder_out.address !== 16'd0)
      $fatal(1, "decoder is undefined for the all-zero instruction at power-up");

    test_case(.number(1), .instruction({`OP_LDI, `REG_8, 8'hFF}), .expected_opcode(`OP_LDI),
              .expected_dst(`REG_8), .expected_a(3'd0), .expected_b(3'd0),
              .expected_immediate(16'h00FF), .expected_address(16'd0));

    test_case(.number(2), .instruction({`OP_MOV, `REG_5, `REG_2, 5'd0}), .expected_opcode(`OP_MOV),
              .expected_dst(`REG_5), .expected_a(`REG_2), .expected_b(3'd0),
              .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(3), .instruction({`OP_ADD, `REG_2, `REG_3, `REG_4, 2'd0}),
              .expected_opcode(`OP_ADD), .expected_dst(`REG_2), .expected_a(`REG_3),
              .expected_b(`REG_4), .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(4), .instruction({`OP_LOAD, `REG_6, `REG_7, 5'd0}),
              .expected_opcode(`OP_LOAD), .expected_dst(`REG_6), .expected_a(3'd0),
              .expected_b(`REG_7), .expected_immediate(16'd0), .expected_address(16'd0));

    // Address-first STORE is routed internally as A=value, B=address.
    test_case(.number(5), .instruction({`OP_STORE, `REG_4, `REG_8, 5'd0}),
              .expected_opcode(`OP_STORE), .expected_dst(3'd0), .expected_a(`REG_8),
              .expected_b(`REG_4), .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(6), .instruction({`OP_CMP, `REG_4, `REG_7, 5'd0}), .expected_opcode(`OP_CMP),
              .expected_dst(3'd0), .expected_a(`REG_4), .expected_b(`REG_7),
              .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(7), .instruction({`OP_JMP, 11'h7FF}), .expected_opcode(`OP_JMP),
              .expected_dst(3'd0), .expected_a(3'd0), .expected_b(3'd0), .expected_immediate(16'd0),
              .expected_address(16'h07FF));

    test_case(.number(8), .instruction({`OP_JZ, 11'h123}), .expected_opcode(`OP_JZ),
              .expected_dst(3'd0), .expected_a(3'd0), .expected_b(3'd0), .expected_immediate(16'd0),
              .expected_address(16'h0123));

    test_case(.number(9), .instruction({`OP_HALT, 11'd0}), .expected_opcode(`OP_HALT),
              .expected_dst(3'd0), .expected_a(3'd0), .expected_b(3'd0), .expected_immediate(16'd0),
              .expected_address(16'd0));

    test_case(.number(10), .instruction({`OP_VLD, `VREG_8, `REG_7, 5'd0}),
              .expected_opcode(`OP_VLD), .expected_dst(`VREG_8), .expected_a(3'd0),
              .expected_b(`REG_7), .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(11), .instruction({`OP_VST, `REG_2, `VREG_8, 5'd0}),
              .expected_opcode(`OP_VST), .expected_dst(3'd0), .expected_a(`VREG_8),
              .expected_b(`REG_2), .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(12), .instruction({`OP_VADD, `VREG_6, `VREG_8, `VREG_7, 2'd0}),
              .expected_opcode(`OP_VADD), .expected_dst(`VREG_6), .expected_a(`VREG_8),
              .expected_b(`VREG_7), .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(13), .instruction({`OP_VDOT, `REG_6, `VREG_8, `VREG_7, 2'd0}),
              .expected_opcode(`OP_VDOT), .expected_dst(`REG_6), .expected_a(`VREG_8),
              .expected_b(`VREG_7), .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(14), .instruction({`OP_LUI, `REG_7, 8'hA5}), .expected_opcode(`OP_LUI),
              .expected_dst(`REG_7), .expected_a(3'd0), .expected_b(3'd0),
              .expected_immediate(16'hA500), .expected_address(16'd0));

    test_case(.number(15), .instruction({`OP_TID, `REG_5, 8'h00}), .expected_opcode(`OP_TID),
              .expected_dst(`REG_5), .expected_a(3'd0), .expected_b(3'd0),
              .expected_immediate(16'd0), .expected_address(16'd0));

    // Reserved fields do not alter operand fields; assemblers emit them as zero.
    test_case(.number(16), .instruction({`OP_MOV, `REG_3, `REG_5, 5'h1F}), .expected_opcode(`OP_MOV),
              .expected_dst(`REG_3), .expected_a(`REG_5), .expected_b(3'd0),
              .expected_immediate(16'd0), .expected_address(16'd0));

    test_case(.number(17), .instruction({`OP_JLT, 11'h123}), .expected_opcode(`OP_JLT),
              .expected_dst(3'd0), .expected_a(3'd0), .expected_b(3'd0), .expected_immediate(16'd0),
              .expected_address(16'h0123));

    test_case(.number(18), .instruction({`OP_JR, `REG_8, 8'd0}), .expected_opcode(`OP_JR),
              .expected_dst(3'd0), .expected_a(`REG_8), .expected_b(3'd0),
              .expected_immediate(16'd0), .expected_address(16'd0));

    if (decoder_out.gpu_command !== gpu_types::GPU_COMMAND_NONE)
      $fatal(1, "regular instruction did not emit GPU_COMMAND_NONE");

    instruction_data = {`OP_GLAUNCH, 11'd23};
    #1;
    if (decoder_out.gpu_command !== gpu_types::GPU_COMMAND_LAUNCH)
      $fatal(1, "GLAUNCH did not emit GPU_COMMAND_LAUNCH");
    if (decoder_out.address !== 16'd23) $fatal(1, "GLAUNCH did not decode its start address");

    instruction_data = {`OP_GWAIT, 11'd23};
    #1;
    if (decoder_out.gpu_command !== gpu_types::GPU_COMMAND_NONE)
      $fatal(1, "GWAIT incorrectly emitted a GPU command");
    if (decoder_out.address !== 16'd23) $fatal(1, "GWAIT did not decode its resume address");

    $display("decoder_tb passed");
    $finish;
  end
endmodule
