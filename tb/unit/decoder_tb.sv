`include "decoder.sv"

module decoder_tb;
  logic  [15:0] instruction_data;
  wire cpu_types_pkg::decoder_out_t decoder_out;

  decoder dut (
      .instruction_data(instruction_data),
      .out             (decoder_out)
  );

  task test_case(input [7:0] number, input [15:0] instruction,
                 input [4:0] expected_opcode, input [2:0] expected_dst,
                 input [2:0] expected_a, input [2:0] expected_b,
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
    test_case(1, {`OP_LDI, 3'd7, 8'hFF}, `OP_LDI, 3'd7, 3'd0, 3'd0, 16'h00FF, 16'd0);
    test_case(2, {`OP_MOV, 3'd4, 3'd1, 5'd0}, `OP_MOV, 3'd4, 3'd1, 3'd0, 16'd0, 16'd0);
    test_case(3, {`OP_ADD, 3'd1, 3'd2, 3'd3, 2'd0}, `OP_ADD, 3'd1, 3'd2, 3'd3, 16'd0, 16'd0);
    test_case(4, {`OP_LOAD, 3'd5, 3'd6, 5'd0}, `OP_LOAD, 3'd5, 3'd0, 3'd6, 16'd0, 16'd0);

    // Address-first STORE is routed internally as A=value, B=address.
    test_case(5, {`OP_STORE, 3'd3, 3'd7, 5'd0}, `OP_STORE, 3'd0, 3'd7, 3'd3, 16'd0, 16'd0);
    test_case(6, {`OP_CMP, 3'd3, 3'd6, 5'd0}, `OP_CMP, 3'd0, 3'd3, 3'd6, 16'd0, 16'd0);
    test_case(7, {`OP_JMP, 11'h7FF}, `OP_JMP, 3'd0, 3'd0, 3'd0, 16'd0, 16'h07FF);
    test_case(8, {`OP_JE, 11'h123}, `OP_JE, 3'd0, 3'd0, 3'd0, 16'd0, 16'h0123);
    test_case(9, {`OP_HALT, 11'd0}, `OP_HALT, 3'd0, 3'd0, 3'd0, 16'd0, 16'd0);
    test_case(10, {`OP_VLD, 3'd7, 3'd6, 5'd0}, `OP_VLD, 3'd7, 3'd0, 3'd6, 16'd0, 16'd0);
    test_case(11, {`OP_VST, 3'd1, 3'd7, 5'd0}, `OP_VST, 3'd0, 3'd7, 3'd1, 16'd0, 16'd0);
    test_case(12, {`OP_VADD, 3'd5, 3'd7, 3'd6, 2'd0}, `OP_VADD, 3'd5, 3'd7, 3'd6, 16'd0, 16'd0);
    test_case(13, {`OP_VDOT, 3'd5, 3'd7, 3'd6, 2'd0}, `OP_VDOT, 3'd5, 3'd7, 3'd6, 16'd0, 16'd0);
    test_case(14, {`OP_LUI, 3'd6, 8'hA5}, `OP_LUI, 3'd6, 3'd0, 3'd0, 16'hA500, 16'd0);
    test_case(15, {`OP_TID, 3'd4, 8'h00}, `OP_TID, 3'd4, 3'd0, 3'd0, 16'd0, 16'd0);

    // Reserved fields do not alter operand fields; assemblers emit them as zero.
    test_case(16, {`OP_MOV, 3'd2, 3'd4, 5'h1F}, `OP_MOV, 3'd2, 3'd4, 3'd0, 16'd0, 16'd0);

    if (decoder_out.gpu_command !== gpu_types::GPU_COMMAND_NONE)
      $fatal(1, "regular instruction did not emit GPU_COMMAND_NONE");

    instruction_data = {`OP_GLAUNCH, 11'd23};
    #1;
    if (decoder_out.gpu_command !== gpu_types::GPU_COMMAND_LAUNCH)
      $fatal(1, "GLAUNCH did not emit GPU_COMMAND_LAUNCH");
    if (decoder_out.address !== 16'd23)
      $fatal(1, "GLAUNCH did not decode its start address");

    instruction_data = {`OP_GWAIT, 11'd0};
    #1;
    if (decoder_out.gpu_command !== gpu_types::GPU_COMMAND_NONE)
      $fatal(1, "GWAIT incorrectly emitted a GPU command");

    $display("decoder_tb passed");
    $finish;
  end
endmodule
