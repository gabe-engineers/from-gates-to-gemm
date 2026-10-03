// 8N1 UART transmitter with a ready/valid byte input.
module uart_tx_byte #(
    parameter integer CLOCK_HZ = 100_000_000,
    parameter integer BAUD = 115_200
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       valid,
    input  wire [7:0] data,
    output wire       ready,
    output wire       tx
);
  localparam integer CYCLES_PER_BIT = (CLOCK_HZ + BAUD / 2) / BAUD;
  localparam integer COUNTER_BITS = $clog2(CYCLES_PER_BIT);
  reg [COUNTER_BITS-1:0] baud_count = 0;
  reg [3:0] bit_index = 0;
  reg [9:0] frame = 10'h3ff;
  reg busy = 1'b0;

  assign ready = !busy;
  assign tx = busy ? frame[0] : 1'b1;

  always @(posedge clk) begin
    if (reset) begin
      baud_count <= 0;
      bit_index <= 0;
      frame <= 10'h3ff;
      busy <= 1'b0;
    end else if (!busy) begin
      if (valid) begin
        frame <= {1'b1, data, 1'b0};
        baud_count <= 0;
        bit_index <= 0;
        busy <= 1'b1;
      end
    end else if (baud_count == CYCLES_PER_BIT - 1) begin
      baud_count <= 0;
      frame <= {1'b1, frame[9:1]};
      if (bit_index == 4'd9) busy <= 1'b0;
      else bit_index <= bit_index + 4'd1;
    end else baud_count <= baud_count + 1'b1;
  end
endmodule
