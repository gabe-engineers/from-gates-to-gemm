`ifndef CPU_TYPES_SVH
`define CPU_TYPES_SVH

`include "gpu_types.svh"

package cpu_types_pkg;

  typedef struct packed {
    logic [15:0] address;
    logic [15:0] write_data;
    logic        write_enable;
  } cpu_mem_request_t;

  typedef struct packed {
    logic [ 4:0] opcode;
    logic [ 2:0] dst_reg;
    logic [ 2:0] src_reg_a;
    logic [ 2:0] src_reg_b;
    logic [15:0] immediate;
    logic [15:0] address;
    // Encoded by gpu_types::GPU_COMMAND_*.
    logic [1:0] gpu_command;
  } decoder_out_t;

  typedef struct packed {
    logic [15:0] mem_addr;
    logic        mem_write_enable;
    logic        datapath_write_enable;
    logic [ 1:0] datapath_writeback_source;
    logic [ 3:0] alu_op;
    logic [15:0] datapath_immediate;
    logic [ 2:0] datapath_src_reg_a;
    logic [ 2:0] datapath_src_reg_b;
    logic [ 2:0] datapath_dst_reg;
    logic        vector_write_enable;
    logic [ 2:0] vector_write_addr;
    logic [ 2:0] vector_write_lane;
    logic [15:0] vector_write_data;
    logic [ 2:0] vector_read_addr;
    logic [ 2:0] vector_read_lane;
    logic        vector_store_active;
    logic        vector_alu_write_enable;
    logic [ 2:0] vector_alu_write_addr;
    logic [ 4:0] vector_alu_operation;
    logic [ 2:0] vector_alu_read_addr_a;
    logic [ 2:0] vector_alu_read_addr_b;
    logic        datapath_vector_dot_writeback_select;
    // Encoded by gpu_types::GPU_COMMAND_*.
    logic [ 1:0] gpu_command;
    logic        halted;
  } control_unit_out_t;

endpackage

`endif
