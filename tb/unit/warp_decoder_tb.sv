`include "warp_decoder.sv"
`include "tb_regs.svh"

module warp_decoder_tb;
  // Power-up value matches the warp instruction register, which starts at zero.
  logic [15:0] instruction_data = 16'b0;
  wire gpu_types::warp_decoder_out_t decoder_out;

  warp_decoder dut (
      .instruction_data(instruction_data),
      .out(decoder_out)
  );

  // Unused operand fields are left as 3'd0, since r1 also encodes as zero.
  task expect_valid(input [15:0] instruction, input [4:0] opcode,
                    input [2:0] dst_reg, input [2:0] src_reg_a,
                    input [2:0] src_reg_b, input [15:0] immediate,
                    input [15:0] address);
    begin
      instruction_data = instruction;
      #1;
      if (!decoder_out.valid || decoder_out.opcode !== opcode ||
          decoder_out.dst_reg !== dst_reg || decoder_out.src_reg_a !== src_reg_a ||
          decoder_out.src_reg_b !== src_reg_b || decoder_out.immediate !== immediate ||
          decoder_out.address !== address)
        $fatal(1, "supported warp instruction decoded incorrectly: %h", instruction);
    end
  endtask

  task expect_invalid(input [15:0] instruction);
    begin
      instruction_data = instruction;
      #1;
      if (decoder_out.valid)
        $fatal(1, "CPU-only instruction was accepted by warp decoder: %h", instruction);
    end
  endtask

  initial begin
    // Regression: the all-zero instruction must decode before the input ever
    // changes. The warp IR powers up at zero, so a kernel that starts with
    // `LDI r1 0` would otherwise see an undefined decoder output.
    #1;
    if (decoder_out.valid !== 1'b1 || decoder_out.opcode !== `OP_LDI)
      $fatal(1, "warp decoder is undefined for the all-zero instruction at power-up");

    expect_valid(.instruction({`OP_LDI, `REG_7, 8'hA5}), .opcode(`OP_LDI),
                 .dst_reg(`REG_7), .src_reg_a(3'd0), .src_reg_b(3'd0),
                 .immediate(16'h00A5), .address(16'd0));

    expect_valid(.instruction({`OP_ADD, `REG_2, `REG_3, `REG_4, 2'd0}), .opcode(`OP_ADD),
                 .dst_reg(`REG_2), .src_reg_a(`REG_3), .src_reg_b(`REG_4),
                 .immediate(16'd0), .address(16'd0));

    expect_valid(.instruction({`OP_TID, `REG_5, 8'd0}), .opcode(`OP_TID),
                 .dst_reg(`REG_5), .src_reg_a(3'd0), .src_reg_b(3'd0),
                 .immediate(16'd0), .address(16'd0));

    expect_valid(.instruction({`OP_LOAD, `REG_2, `REG_3, 5'd0}), .opcode(`OP_LOAD),
                 .dst_reg(`REG_2), .src_reg_a(3'd0), .src_reg_b(`REG_3),
                 .immediate(16'd0), .address(16'd0));

    expect_valid(.instruction({`OP_STORE, `REG_2, `REG_3, 5'd0}), .opcode(`OP_STORE),
                 .dst_reg(3'd0), .src_reg_a(`REG_3), .src_reg_b(`REG_2),
                 .immediate(16'd0), .address(16'd0));

    expect_valid(.instruction({`OP_CMP, `REG_2, `REG_3, 5'd0}), .opcode(`OP_CMP),
                 .dst_reg(3'd0), .src_reg_a(`REG_2), .src_reg_b(`REG_3),
                 .immediate(16'd0), .address(16'd0));

    expect_valid(.instruction({`OP_JMP, 11'h7FF}), .opcode(`OP_JMP),
                 .dst_reg(3'd0), .src_reg_a(3'd0), .src_reg_b(3'd0),
                 .immediate(16'd0), .address(16'h07FF));

    expect_valid(.instruction({`OP_JZ, 11'h123}), .opcode(`OP_JZ),
                 .dst_reg(3'd0), .src_reg_a(3'd0), .src_reg_b(3'd0),
                 .immediate(16'd0), .address(16'h0123));

    expect_valid(.instruction({`OP_JLT, 11'h123}), .opcode(`OP_JLT),
                 .dst_reg(3'd0), .src_reg_a(3'd0), .src_reg_b(3'd0),
                 .immediate(16'd0), .address(16'h0123));

    expect_valid(.instruction({`OP_HALT, 11'd0}), .opcode(`OP_HALT),
                 .dst_reg(3'd0), .src_reg_a(3'd0), .src_reg_b(3'd0),
                 .immediate(16'd0), .address(16'd0));

    expect_invalid(.instruction({`OP_VADD, `REG_2, `REG_3, `REG_4, 2'd0}));
    expect_invalid(.instruction({`OP_VDOT, `REG_2, `REG_3, `REG_4, 2'd0}));
    expect_invalid(.instruction({`OP_GLAUNCH, 11'd0}));
    expect_invalid(.instruction({`OP_GWAIT, 11'd0}));

    $display("warp_decoder_tb passed");
    $finish;
  end
endmodule
