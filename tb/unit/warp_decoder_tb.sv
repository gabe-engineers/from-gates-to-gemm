`include "warp_decoder.sv"

module warp_decoder_tb;
  logic [15:0] instruction_data;
  wire gpu_types::warp_decoder_out_t decoder_out;

  warp_decoder dut (
      .instruction_data(instruction_data),
      .out(decoder_out)
  );

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
    expect_valid({`OP_LDI, 3'd6, 8'hA5}, `OP_LDI, 3'd6, 3'd0, 3'd0, 16'h00A5, 16'd0);
    expect_valid({`OP_ADD, 3'd1, 3'd2, 3'd3, 2'd0}, `OP_ADD, 3'd1, 3'd2, 3'd3, 16'd0, 16'd0);
    expect_valid({`OP_TID, 3'd4, 8'd0}, `OP_TID, 3'd4, 3'd0, 3'd0, 16'd0, 16'd0);

    expect_valid({`OP_LOAD, 3'd1, 3'd2, 5'd0}, `OP_LOAD, 3'd1, 3'd0, 3'd2, 16'd0, 16'd0);
    expect_valid({`OP_STORE, 3'd1, 3'd2, 5'd0}, `OP_STORE, 3'd0, 3'd2, 3'd1, 16'd0, 16'd0);
    expect_valid({`OP_CMP, 3'd1, 3'd2, 5'd0}, `OP_CMP, 3'd0, 3'd1, 3'd2, 16'd0, 16'd0);
    expect_valid({`OP_JMP, 11'h7FF}, `OP_JMP, 3'd0, 3'd0, 3'd0, 16'd0, 16'h07FF);
    expect_valid({`OP_JE, 11'h123}, `OP_JE, 3'd0, 3'd0, 3'd0, 16'd0, 16'h0123);
    expect_valid({`OP_HALT, 11'd0}, `OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0, 16'd0);

    expect_invalid({`OP_VADD, 3'd1, 3'd2, 3'd3, 2'd0});
    expect_invalid({`OP_VDOT, 3'd1, 3'd2, 3'd3, 2'd0});
    expect_invalid({`OP_GLAUNCH, 11'd0});
    expect_invalid({`OP_GWAIT, 11'd0});

    $display("warp_decoder_tb passed");
    $finish;
  end
endmodule
