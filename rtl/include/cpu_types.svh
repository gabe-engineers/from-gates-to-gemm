`ifndef CPU_TYPES_SVH
`define CPU_TYPES_SVH

`include "gpu_types.svh"

package cpu_types_pkg;

  typedef struct packed {
    logic [15:0] address;
    logic [15:0] write_data;
    logic        write_enable;
  } cpu_mem_request_t;

  // Scalar register-file port plus writeback selection. The thread_id is zero
  // on the scalar CPU and carries the lane id inside a warp.
  typedef struct packed {
    logic        write_enable;
    logic [ 1:0] writeback_source;
    logic [ 2:0] thread_id;
    logic [ 3:0] alu_op;
    logic [15:0] immediate;
    logic [ 2:0] read_addr_a;
    logic [ 2:0] read_addr_b;
    logic [ 2:0] write_addr;
  } scalar_request_t;

  typedef struct packed {
    logic [15:0] read_data_a;
    logic [15:0] read_data_b;
    logic [15:0] write_reg_data;
    logic        zero_flag;
    logic        less_than_flag;
  } scalar_response_t;

  // Vector register-file memory port (VLD/VST).
  typedef struct packed {
    logic        write_enable;
    logic [ 2:0] write_addr;
    logic [ 2:0] write_lane;
    logic [15:0] write_data;
    logic [ 2:0] read_addr;
    logic [ 2:0] read_lane;
  } vector_mem_request_t;

  typedef struct packed {
    logic [15:0] read_data;
  } vector_mem_response_t;

  // Vector ALU port (VADD/VSUB/VMUL/VDOT) plus the dot-product writeback select.
  typedef struct packed {
    logic        write_enable;
    logic [ 2:0] write_addr;
    logic [ 4:0] operation;
    logic [ 2:0] read_addr_a;
    logic [ 2:0] read_addr_b;
    logic        dot_writeback_select;
  } vector_alu_request_t;

  typedef struct packed {
    logic [ 4:0] opcode;
    logic [ 2:0] dst_reg;
    logic [ 2:0] src_reg_a;
    logic [ 2:0] src_reg_b;
    logic [15:0] immediate;
    logic [15:0] address;
    logic        gpu_command;
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
    logic        gpu_command;
    logic [15:0] gpu_launch_address;
    logic        cmp_less_flag;
    logic        halted;
  } control_unit_out_t;

endpackage

`endif
