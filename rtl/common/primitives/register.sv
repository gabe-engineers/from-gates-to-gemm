`ifndef REGISTER_V
`define REGISTER_V

module register #(
    parameter BITWIDTH = 16
) (
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  write_enable,
    input  wire [BITWIDTH - 1:0] data_in,
    output logic  [BITWIDTH - 1:0] data_out = {BITWIDTH{1'b0}}
);

  always @(posedge clk) begin
    if (reset) data_out <= {BITWIDTH{1'b0}};
    else if (write_enable) data_out <= data_in;
  end

endmodule

`endif
