`include "vector_register.sv"

module vector_register_tb;
  logic clk;
  logic reset;
  logic write_enable;
  logic [7:0][15:0] data_in;
  wire [7:0][15:0] data_out;

  vector_register_16bit dut (
      .clk(clk),
      .reset(reset),
      .write_enable(write_enable),
      .data_in(data_in),
      .data_out(data_out)
  );

  task tick;
    begin
      clk = 1'b0;
      #5;
      clk = 1'b1;
      #5;
    end
  endtask

  task expect_lane(input integer lane, input [15:0] expected_data);
    begin
      if (data_out[lane] !== expected_data)
        $fatal(1, "vector register lane %0d: got %h, expected %h", lane,
               data_out[lane], expected_data);
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    write_enable = 1'b0;
    data_in = '0;
    tick;
    for (int lane = 0; lane < 8; lane++) expect_lane(lane, 16'h0000);

    reset = 1'b0;
    write_enable = 1'b1;
    for (int lane = 0; lane < 8; lane++) data_in[lane] = 16'h1100 + lane;
    tick;
    for (int lane = 0; lane < 8; lane++) expect_lane(lane, 16'h1100 + lane);

    write_enable = 1'b0;
    data_in = '1;
    tick;
    for (int lane = 0; lane < 8; lane++) expect_lane(lane, 16'h1100 + lane);

    // Reset wins even if a write is requested on the same edge.
    reset = 1'b1;
    write_enable = 1'b1;
    tick;
    for (int lane = 0; lane < 8; lane++) expect_lane(lane, 16'h0000);

    $display("vector_register_tb passed");
    $finish;
  end
endmodule
