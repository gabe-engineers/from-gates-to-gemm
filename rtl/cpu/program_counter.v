`include "register.v"
`include "adder.v"

module program_counter (
    input             clk,
    input             reset,
    input             advance,
    input             write_enable,
    input      [ 8:0] write_data,
    output wire [ 8:0] data_out
);

  wire [ 8:0] incrementer_out;
  wire [15:0] incrementer_out_wide;
  wire [ 8:0] register_out;
  wire reg_write_enable = write_enable | advance;
  wire [ 8:0] reg_data_in = write_enable ? write_data : incrementer_out;

  register #(.BITWIDTH(9)) pc_register (
      .clk         (clk),
      .reset       (reset),
      .write_enable(reg_write_enable),
      .data_in     (reg_data_in),
      .data_out    (register_out)
  );

  adder_16bit incrementer (
      {7'b0, register_out},
      16'd1,
      incrementer_out_wide
  );

  assign incrementer_out = incrementer_out_wide[8:0];
  assign data_out = register_out;

endmodule
