`include "register_file.sv"
`include "vector_register_file.sv"
`include "vector_alu.sv"
`include "alu.sv"
`include "control_helpers.svh"

module datapath_16bit (
    input         clk,
    input         reset,
    input         write_enable,
    input  [ 1:0] writeback_source,
    input  [ 2:0] thread_id,
    input  [ 3:0] alu_op,
    input  [15:0] immediate,
    input  [ 2:0] read_addr_a,
    input  [ 2:0] read_addr_b,
    input  [ 2:0] write_addr,
    output [15:0] write_reg_data,
    output [15:0] read_data_a,
    output [15:0] read_data_b,
    input         vector_write_enable,
    input  [ 2:0] vector_write_addr,
    input  [ 2:0] vector_write_lane,
    input  [15:0] vector_write_data,
    input  [ 2:0] vector_read_addr,
    input  [ 2:0] vector_read_lane,
    output [15:0] vector_read_data,
    input         vector_alu_write_enable,
    input  [ 2:0] vector_alu_write_addr,
    input  [ 4:0] vector_alu_operation,
    input  [ 2:0] vector_alu_read_addr_a,
    input  [ 2:0] vector_alu_read_addr_b,
    input         vector_dot_writeback_select
);
  wire [ 15:0] alu_out;
  wire [ 15:0] write_data;
  wire [127:0] vector_alu_read_data_a;
  wire [127:0] vector_alu_read_data_b;
  wire [127:0] vector_alu_out;
  wire [ 15:0] vector_dot_product;

  assign write_data = vector_dot_writeback_select ? vector_dot_product :
                      writeback_source == control_helpers_pkg::WB_IMMEDIATE ? immediate :
                      writeback_source == control_helpers_pkg::WB_THREAD_ID ?
                          {13'b0, thread_id} : alu_out;

  register_file registers (
      .clk           (clk),
      .reset         (reset),
      .write_enable  (write_enable),
      .write_addr    (write_addr),
      .write_data    (write_data),
      .read_addr_a   (read_addr_a),
      .read_addr_b   (read_addr_b),
      .read_data_a   (read_data_a),
      .read_data_b   (read_data_b),
      .write_reg_data(write_reg_data)
  );

  alu_16bit alu (
      alu_op,
      read_data_a,
      read_data_b,
      alu_out
  );

  vector_register_file vector_registers (
      .clk                    (clk),
      .reset                  (reset),
      .write_enable           (vector_write_enable),
      .write_addr             (vector_write_addr),
      .write_lane             (vector_write_lane),
      .write_data             (vector_write_data),
      .read_addr              (vector_read_addr),
      .read_lane              (vector_read_lane),
      .read_data              (vector_read_data),
      .vector_alu_write_enable(vector_alu_write_enable),
      .vector_alu_write_addr  (vector_alu_write_addr),
      .vector_alu_write_data  (vector_alu_out),
      .vector_alu_read_addr_a (vector_alu_read_addr_a),
      .vector_alu_read_addr_b (vector_alu_read_addr_b),
      .vector_alu_read_data_a (vector_alu_read_data_a),
      .vector_alu_read_data_b (vector_alu_read_data_b)
  );

  vector_alu_16bit vector_alu (
      .operation  (vector_alu_operation),
      .a          (vector_alu_read_data_a),
      .b          (vector_alu_read_data_b),
      .out        (vector_alu_out),
      .dot_product(vector_dot_product)
  );
endmodule
