`include "fsm_states.vh"
`include "control_unit.v"
`include "datapath.v"

module cpu (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] mem_read_data,
    output wire [ 8:0] mem_address,
    output wire [15:0] mem_write_data,
    output wire        mem_write_enable,
    output wire        halted
);

  wire [2:0] datapath_src_reg_a;
  wire [2:0] datapath_src_reg_b;
  wire [2:0] datapath_dst_reg;
  wire datapath_write_enable;
  wire datapath_writeback_select;
  wire [3:0] alu_op;
  wire [15:0] datapath_immediate;
  wire [15:0] datapath_read_data_a;
  wire [15:0] datapath_read_data_b;
  wire        vector_write_enable;
  wire [ 2:0] vector_write_addr;
  wire [ 2:0] vector_write_lane;
  wire [15:0] vector_write_data;
  wire [ 2:0] vector_read_addr;
  wire [ 2:0] vector_read_lane;
  wire [15:0] vector_read_data;
  wire        vector_store_active;
  wire        vector_alu_write_enable;
  wire [ 2:0] vector_alu_write_addr;
  wire [ 2:0] vector_alu_operation;
  wire [ 2:0] vector_alu_read_addr_a;
  wire [ 2:0] vector_alu_read_addr_b;
  wire        datapath_vector_dot_writeback_select;

  // STORE takes its value from scalar source operand A; VSTORE takes the
  // matching lane from its vector source. Both use scalar source operand B as
  // their address register (truncated to the RAM's 9-bit bus in the control unit).
  assign mem_write_data = vector_store_active ? vector_read_data : datapath_read_data_a;

  control_unit control_unit_module (
      .clk                      (clk),
      .reset                    (reset),
      .mem_read_data            (mem_read_data),
      .datapath_read_data_a     (datapath_read_data_a),
      .datapath_read_data_b     (datapath_read_data_b),
      .mem_addr                 (mem_address),
      .mem_write_enable         (mem_write_enable),
      .datapath_write_enable    (datapath_write_enable),
      .datapath_writeback_select(datapath_writeback_select),
      .alu_op                   (alu_op),
      .datapath_immediate       (datapath_immediate),
      .datapath_src_reg_a       (datapath_src_reg_a),
      .datapath_src_reg_b       (datapath_src_reg_b),
      .datapath_dst_reg         (datapath_dst_reg),
      .vector_write_enable      (vector_write_enable),
      .vector_write_addr        (vector_write_addr),
      .vector_write_lane        (vector_write_lane),
      .vector_write_data        (vector_write_data),
      .vector_read_addr         (vector_read_addr),
      .vector_read_lane         (vector_read_lane),
      .vector_store_active      (vector_store_active),
      .vector_alu_write_enable  (vector_alu_write_enable),
      .vector_alu_write_addr    (vector_alu_write_addr),
      .vector_alu_operation     (vector_alu_operation),
      .vector_alu_read_addr_a   (vector_alu_read_addr_a),
      .vector_alu_read_addr_b   (vector_alu_read_addr_b),
      .datapath_vector_dot_writeback_select(datapath_vector_dot_writeback_select),
      .halted                   (halted)
  );

  datapath_16bit datapath (
      .clk(clk),
      .reset(reset),
      .write_enable(datapath_write_enable),
      .writeback_select(datapath_writeback_select),
      .alu_op(alu_op),
      .immediate(datapath_immediate),
      .read_addr_a(datapath_src_reg_a),
      .read_addr_b(datapath_src_reg_b),
      .write_addr(datapath_dst_reg),
      .write_reg_data(),
      .read_data_a(datapath_read_data_a),
      .read_data_b(datapath_read_data_b),
      .vector_write_enable(vector_write_enable),
      .vector_write_addr  (vector_write_addr),
      .vector_write_lane  (vector_write_lane),
      .vector_write_data  (vector_write_data),
      .vector_read_addr   (vector_read_addr),
      .vector_read_lane   (vector_read_lane),
      .vector_read_data   (vector_read_data),
      .vector_alu_write_enable(vector_alu_write_enable),
      .vector_alu_write_addr  (vector_alu_write_addr),
      .vector_alu_operation   (vector_alu_operation),
      .vector_alu_read_addr_a (vector_alu_read_addr_a),
      .vector_alu_read_addr_b (vector_alu_read_addr_b),
      .vector_dot_writeback_select(datapath_vector_dot_writeback_select)
  );

endmodule
