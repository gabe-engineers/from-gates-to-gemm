// Basys 3 (xc7a35tcpg236-1): run preloaded GEMM and stream C and cycles over UART.
module basys3_gemm #(
    parameter RAM_INIT_PREFIX = "build/fpga/gemm_scalar"
) (
    input  wire clk100,
    input  wire btn_reset,
    output wire led_halted,
    output wire uart_txd
);
  reg [1:0] clock_divider = 2'b00;
  always @(posedge clk100) clock_divider <= clock_divider + 2'd1;
  wire core_clk;
  BUFG core_clock_buffer (.I(clock_divider[1]), .O(core_clk));

  reg [3:0] core_reset_pipe = 4'hf;
  always @(posedge core_clk)
    core_reset_pipe <= {core_reset_pipe[2:0], btn_reset};
  wire core_reset = core_reset_pipe[3];

  wire halted;
  assign led_halted = halted;

  // Count core clocks spent running GEMM. UART output starts only after this
  // counter freezes, so serial transmission time is excluded.
  reg [31:0] elapsed_cycles = 32'd0;
  always @(posedge core_clk) begin
    if (core_reset) elapsed_cycles <= 32'd0;
    else if (!halted) elapsed_cycles <= elapsed_cycles + 32'd1;
  end

  reg [3:0] word_index = 4'd0;
  wire [15:0] result_word;
  fpga_gemm_top #(
      .RAM_INIT_PREFIX(RAM_INIT_PREFIX)
  ) gemm (
      .clk(core_clk),
      .reset(core_reset),
      .result_index(word_index),
      .result_word(result_word),
      .halted(halted)
  );

  reg [4:0] character_index = 5'd0;
  reg sending_cycles = 1'b0;
  wire uart_ready;
  wire uart_valid = halted && !core_reset;
  reg [7:0] character;

  function automatic [7:0] hex_character(input [3:0] nibble);
    hex_character = nibble < 4'd10 ? (8'h30 + {4'b0, nibble}) :
                                     (8'h41 + {4'b0, nibble} - 8'd10);
  endfunction

  always @* begin
    if (sending_cycles) begin
      case (character_index)
        5'd0: character = "#";
        5'd1: character = "C";
        5'd2: character = "Y";
        5'd3: character = "C";
        5'd4: character = "L";
        5'd5: character = "E";
        5'd6: character = "S";
        5'd7: character = "=";
        5'd8: character = hex_character(elapsed_cycles[31:28]);
        5'd9: character = hex_character(elapsed_cycles[27:24]);
        5'd10: character = hex_character(elapsed_cycles[23:20]);
        5'd11: character = hex_character(elapsed_cycles[19:16]);
        5'd12: character = hex_character(elapsed_cycles[15:12]);
        5'd13: character = hex_character(elapsed_cycles[11:8]);
        5'd14: character = hex_character(elapsed_cycles[7:4]);
        5'd15: character = hex_character(elapsed_cycles[3:0]);
        default: character = 8'h0a;
      endcase
    end else begin
      case (character_index)
        5'd0: character = "@";
        5'd1: character = "0";
        5'd2: character = hex_character(word_index);
        5'd3: character = "=";
        5'd4: character = hex_character(result_word[15:12]);
        5'd5: character = hex_character(result_word[11:8]);
        5'd6: character = hex_character(result_word[7:4]);
        5'd7: character = hex_character(result_word[3:0]);
        default: character = 8'h0a;
      endcase
    end
  end

  always @(posedge core_clk) begin
    if (core_reset) begin
      character_index <= 5'd0;
      word_index <= 4'd0;
      sending_cycles <= 1'b0;
    end else if (uart_valid && uart_ready) begin
      if (sending_cycles) begin
        if (character_index == 5'd16) begin
          character_index <= 5'd0;
          sending_cycles <= 1'b0;
          word_index <= 4'd0;
        end else character_index <= character_index + 5'd1;
      end else if (character_index == 5'd8) begin
        character_index <= 5'd0;
        if (word_index == 4'd15) sending_cycles <= 1'b1;
        else word_index <= word_index + 4'd1;
      end else character_index <= character_index + 5'd1;
    end
  end

  uart_tx_byte #(
      .CLOCK_HZ(25_000_000),
      .BAUD(115_200)
  ) uart (
      .clk(core_clk),
      .reset(core_reset),
      .valid(uart_valid),
      .data(character),
      .ready(uart_ready),
      .tx(uart_txd)
  );
endmodule
