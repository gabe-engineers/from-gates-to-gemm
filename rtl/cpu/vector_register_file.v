`ifndef VECTOR_REGISTER_FILE_V
`define VECTOR_REGISTER_FILE_V

`include "register.v"

// Eight vector registers, each containing eight 16-bit lanes. VLOAD writes one
// selected lane per memory phase; vector ALU instructions write every lane of a
// selected result register in their execute phase.
module vector_register_file (
    input         clk,
    input         reset,
    input         write_enable,
    input  [ 2:0] write_addr,
    input  [ 2:0] write_lane,
    input  [15:0] write_data,
    input  [ 2:0] read_addr,
    input  [ 2:0] read_lane,
    output [15:0] read_data,
    input         vector_alu_write_enable,
    input  [ 2:0] vector_alu_write_addr,
    input  [127:0] vector_alu_write_data,
    input  [ 2:0] vector_alu_read_addr_a,
    input  [ 2:0] vector_alu_read_addr_b,
    output [127:0] vector_alu_read_data_a,
    output [127:0] vector_alu_read_data_b
);
  wire [5:0] write_index;
  wire [5:0] read_index;
  wire [15:0] lane_data [0:63];

  assign write_index = {write_addr, write_lane};
  assign read_index = {read_addr, read_lane};
  assign read_data = lane_data[read_index];

  genvar lane;
  generate
    for (lane = 0; lane < 64; lane = lane + 1) begin : vector_lanes
      wire lane_memory_write_enable;
      wire lane_alu_write_enable;
      wire [15:0] lane_write_data;

      assign lane_memory_write_enable = write_enable && write_index == lane;
      assign lane_alu_write_enable =
          vector_alu_write_enable && vector_alu_write_addr == lane / 8;
      assign lane_write_data = lane_alu_write_enable ?
          vector_alu_write_data[(lane % 8) * 16 +: 16] : write_data;

      register lane_register (
          .clk         (clk),
          .reset       (reset),
          .write_enable(lane_memory_write_enable || lane_alu_write_enable),
          .data_in     (lane_write_data),
          .data_out    (lane_data[lane])
      );
    end
  endgenerate

  genvar vector_lane;
  generate
    for (vector_lane = 0; vector_lane < 8; vector_lane = vector_lane + 1) begin : vector_reads
      assign vector_alu_read_data_a[vector_lane * 16 +: 16] =
          lane_data[{vector_alu_read_addr_a, 3'b000} + vector_lane];
      assign vector_alu_read_data_b[vector_lane * 16 +: 16] =
          lane_data[{vector_alu_read_addr_b, 3'b000} + vector_lane];
    end
  endgenerate
endmodule

`endif
