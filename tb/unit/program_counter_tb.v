`include "program_counter.v"

module program_counter_tb;

  reg         clk;
  reg         reset;
  reg         advance;
  reg         write_enable;
  reg  [ 8:0] write_data;
  wire [ 8:0] data_out;

  program_counter dut (
    .clk         (clk),
    .reset       (reset),
    .advance     (advance),
    .write_enable(write_enable),
    .write_data  (write_data),
    .data_out    (data_out)
  );


  task test_case(input [8:0] test_number, input tc_reset, input tc_advance, input tc_write_enable,
                 input [8:0] tc_write_data, input [8:0] expected_data_out);

    begin

      reset        = tc_reset;
      advance      = tc_advance;
      write_enable = tc_write_enable;
      write_data   = tc_write_data;

      clk = 0;
      #10;
      clk = 1;
      #10;

      if (data_out != expected_data_out) begin
        $display(
            "Failed Test Case #%d - reset: %d, advance: %d, write_enable: %d, write_data: %d | data_out: %d, expected_data_out: %d",
            test_number, reset, advance, write_enable, write_data, data_out, expected_data_out);
      end

    end

  endtask

  initial begin

    // Reset initializes PC to zero
    test_case(.test_number(1), .tc_reset(1'b1), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(9'h000), .expected_data_out(9'h000));

    // Hold after reset
    test_case(.test_number(2), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(9'h1AA), .expected_data_out(9'h000));

    // Advance: 0 -> 1
    test_case(.test_number(3), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(9'h000), .expected_data_out(9'h001));

    // Advance again: 1 -> 2
    test_case(.test_number(4), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(9'h000), .expected_data_out(9'h002));

    // Hold should retain current PC
    test_case(.test_number(5), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(9'h1FF), .expected_data_out(9'h002));

    // Explicit write: PC = 0x134
    test_case(.test_number(6), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(9'h134), .expected_data_out(9'h134));

    // Hold written value
    test_case(.test_number(7), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(9'h000), .expected_data_out(9'h134));

    // Advance after write: 0x134 -> 0x135
    test_case(.test_number(8), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(9'h000), .expected_data_out(9'h135));

    // Write should beat advance
    test_case(.test_number(9), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b1),
              .tc_write_data(9'h1CD), .expected_data_out(9'h1CD));

    // Reset should beat write and advance
    test_case(.test_number(10), .tc_reset(1'b1), .tc_advance(1'b1), .tc_write_enable(1'b1),
              .tc_write_data(9'h1FF), .expected_data_out(9'h000));

    // Write maximum value
    test_case(.test_number(11), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(9'h1FF), .expected_data_out(9'h1FF));

    // Advance wraps: 0x1FF -> 0x000
    test_case(.test_number(12), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(9'h000), .expected_data_out(9'h000));

    // Explicit write of zero
    test_case(.test_number(13), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(9'h000), .expected_data_out(9'h000));

    // Write arbitrary pattern
    test_case(.test_number(14), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(9'h1A5), .expected_data_out(9'h1A5));

    // Advance arbitrary pattern
    test_case(.test_number(15), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(9'h000), .expected_data_out(9'h1A6));

    $finish;

  end

endmodule
