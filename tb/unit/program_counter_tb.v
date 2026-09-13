`include "program_counter.v"

module program_counter_tb;
  reg clk;
  reg reset;
  reg advance;
  reg write_enable;
  reg [15:0] write_data;
  wire [15:0] data_out;

  program_counter dut (clk, reset, advance, write_enable, write_data, data_out);

  task tick;
    begin
      clk = 0; #5; clk = 1; #5;
    end
  endtask

  initial begin
    reset = 1; advance = 0; write_enable = 0; write_data = 0;
    tick;
    if (data_out !== 16'd0) $fatal(1, "reset failed");
    reset = 0; advance = 1;
    tick;
    if (data_out !== 16'd1) $fatal(1, "advance failed");
    advance = 0; write_enable = 1; write_data = 16'hBEEF;
    tick;
    if (data_out !== 16'hBEEF) $fatal(1, "16-bit jump write failed");
    advance = 1; write_enable = 0;
    tick;
    if (data_out !== 16'hBEF0) $fatal(1, "wide increment failed");
    write_enable = 1; write_data = 16'hFFFF;
    tick;
    write_enable = 0;
    tick;
    if (data_out !== 16'h0000) $fatal(1, "16-bit wrap failed");
    $display("program_counter_tb passed");
    $finish;
  end
endmodule
