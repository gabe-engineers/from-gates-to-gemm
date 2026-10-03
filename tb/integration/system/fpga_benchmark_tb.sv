// Measure the same reset-to-HALT interval as the Basys 3 cycle counter.
module fpga_benchmark_tb;
  parameter IMAGE_PREFIX = "build/fpga/sweep/gemm_scalar";
  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [3:0] result_index = 4'd0;
  wire [15:0] result_word;
  wire halted;
  logic [31:0] elapsed_cycles = 32'd0;

  fpga_gemm_top #(.RAM_INIT_PREFIX(IMAGE_PREFIX)) dut (
      .clk(clk),
      .reset(reset),
      .result_index(result_index),
      .result_word(result_word),
      .halted(halted)
  );

  always #5 clk = ~clk;
  always @(posedge clk) begin
    if (reset) elapsed_cycles <= 32'd0;
    else if (!halted) elapsed_cycles <= elapsed_cycles + 32'd1;
  end

  initial begin
    integer waited;
    repeat (5) @(negedge clk);
    reset = 1'b0;
    waited = 0;
    while (!halted && waited < 1000000) begin
      @(negedge clk);
      waited = waited + 1;
    end
    if (!halted) $fatal(1, "GEMM did not halt");
    for (integer i = 0; i < 16; i = i + 1) begin
      result_index = i;
      #1;
      $display("BENCH_WORD=%0d:%04h", i, result_word);
    end
    $display("BENCH_CYCLES=%0d", elapsed_cycles);
    $finish;
  end
endmodule
