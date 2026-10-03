// Board-independent GEMM wrapper. Add a device clock, reset, and output pins
// in the target project, then choose one build/fpga/gemm_* bank image prefix.
module fpga_gemm_top #(
    parameter RAM_INIT_PREFIX = "build/fpga/gemm_scalar"
) (
    input         clk,
    input         reset,
    input   [3:0] result_index,
    output [15:0] result_word,
    output        halted
);
  wire [15:0] result_address = 16'd116 + {12'b0, result_index};

  chip #(
      .RAM_INIT_PREFIX(RAM_INIT_PREFIX),
      .GEMM_SCRATCH_MODE(1'b1)
  ) chip_module (
      .clk(clk),
      .reset(reset),
      .load_enable(1'b0),
      .load_address(16'b0),
      .load_data(16'b0),
      .inspect_address(result_address),
      .inspect_data(result_word),
      .halted(halted)
  );
endmodule
