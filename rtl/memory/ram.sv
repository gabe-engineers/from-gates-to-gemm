`include "register.sv"

module memory (
    input         clk,
    input  [15:0] cpu_address,
    input         cpu_write_enable,
    input  [15:0] cpu_write_data,
    input  [15:0] gpu_address,
    input         gpu_write_enable,
    input  [15:0] gpu_write_data,
    output [15:0] cpu_read_data,
    output [15:0] gpu_read_data
);

  wire [15:0] register_out[0:511];

  wire write_enable;

  // Access outside the implemented 512-word RAM is architecturally undefined.
  assign cpu_read_data = register_out[cpu_address];
  assign gpu_read_data = register_out[gpu_address];

  genvar i;

  generate

    for (i = 0; i < 512; i = i + 1) begin
      wire cpu_writes_this_word;
      wire gpu_writes_this_word;

      assign cpu_writes_this_word = cpu_write_enable && (cpu_address == i);
      assign gpu_writes_this_word = gpu_write_enable && (gpu_address == i);

      register register (
          .clk         (clk),
          .reset       (1'b0),
          .write_enable(cpu_writes_this_word || gpu_writes_this_word),
          // CPU wins if both ports write the same word on the same clock edge.
          .data_in     (cpu_writes_this_word ? cpu_write_data : gpu_write_data),
          .data_out    (register_out[i])
      );
    end

  endgenerate



endmodule
