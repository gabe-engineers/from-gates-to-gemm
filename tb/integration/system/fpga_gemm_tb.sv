// Checks the preloaded FPGA memory path, including the GEMM scratch registers.
module fpga_gemm_tb;
  parameter IMAGE_PREFIX = "build/fpga/gemm_scalar";
  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [3:0] result_index = 4'd0;
  wire [15:0] result_word;
  wire halted;
  integer cycles;

  fpga_gemm_top #(
      .RAM_INIT_PREFIX(IMAGE_PREFIX)
  ) dut (
      .clk(clk),
      .reset(reset),
      .result_index(result_index),
      .result_word(result_word),
      .halted(halted)
  );

  always #5 clk = ~clk;

  function automatic [15:0] expected(input integer index);
    case (index)
      0, 1, 8, 9, 12: expected = 16'd7;
      2, 7: expected = 16'd10;
      3, 10: expected = 16'd11;
      4, 15: expected = 16'd3;
      5: expected = 16'd8;
      6: expected = 16'd5;
      11: expected = 16'd13;
      13: expected = 16'd3;
      14: expected = 16'd4;
      default: expected = 16'hffff;
    endcase
  endfunction

  initial begin
    repeat (5) @(negedge clk);
    reset = 1'b0;
    cycles = 0;
    while (!halted && cycles < 100000) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    if (!halted) $fatal(1, "FPGA GEMM did not halt");
    for (integer i = 0; i < 16; i = i + 1) begin
      result_index = i;
      #1;
      if (result_word !== expected(i))
        $fatal(1, "C[%0d] = %04h, expected %04h", i, result_word, expected(i));
    end
    @(negedge clk);
    reset = 1'b1;
    // Make stale first-run outputs unable to satisfy the second-run check.
    for (integer i = 0; i < 16; i = i + 1) begin
      case ((116 + i) % 8)
        0: dut.chip_module.memory_module.gemm_fpga.bank0[(116+i)/8] = 16'ha5a5;
        1: dut.chip_module.memory_module.gemm_fpga.bank1[(116+i)/8] = 16'ha5a5;
        2: dut.chip_module.memory_module.gemm_fpga.bank2[(116+i)/8] = 16'ha5a5;
        3: dut.chip_module.memory_module.gemm_fpga.bank3[(116+i)/8] = 16'ha5a5;
        4: dut.chip_module.memory_module.gemm_fpga.bank4[(116+i)/8] = 16'ha5a5;
        5: dut.chip_module.memory_module.gemm_fpga.bank5[(116+i)/8] = 16'ha5a5;
        6: dut.chip_module.memory_module.gemm_fpga.bank6[(116+i)/8] = 16'ha5a5;
        7: dut.chip_module.memory_module.gemm_fpga.bank7[(116+i)/8] = 16'ha5a5;
      endcase
    end
    repeat (5) @(negedge clk);
    if (dut.chip_module.memory_module.gemm_fpga.scratch[7] !== 16'd116)
      $fatal(1, "reset did not restore the C base pointer");
    reset = 1'b0;
    cycles = 0;
    while (!halted && cycles < 100000) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    if (!halted) $fatal(1, "FPGA GEMM did not halt after reset");
    for (integer i = 0; i < 16; i = i + 1) begin
      result_index = i;
      #1;
      if (result_word !== expected(i))
        $fatal(1, "after reset C[%0d] = %04h, expected %04h", i, result_word, expected(i));
    end
    $display("FPGA GEMM preload, scratch, and reset path PASS after %0d cycles", cycles);
    $finish;
  end
endmodule
