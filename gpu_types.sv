`ifndef GPU_TYPES_SV
`define GPU_TYPES_SV

`include "control_helpers.svh"

package gpu_types;

  typedef struct packed {
    logic [2:0] dst_reg;
    logic [2:0] src_reg_a;
    logic [2:0] src_reg_b;
    logic [15:0] immediate;
    logic [3:0] alu_op;
    logic [1:0] writeback_source;
    logic write_enable;
    logic [15:0] jmp_address;
  } lane_request_t;


  typedef struct packed {
    // Each field contains one 16-bit word per lane; index 0 is lane 0.
    logic [7:0][15:0] mem_address;
    logic [7:0][15:0] mem_write_data;
  } warp_mem_request;

endpackage

`endif
