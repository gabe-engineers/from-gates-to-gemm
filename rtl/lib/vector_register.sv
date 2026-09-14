module vector_register_16bit (
    input clk,
    input reset,
    input write_enable,
    input logic [7:0][15:0] data_in,
    output logic [7:0][15:0] data_out
);

  always @(posedge clk) begin
    if (reset) data_out <= 128'b0;
    if (write_enable) data_out <= data_in;
  end


endmodule
