`ifndef GPU_TYPES_SV
`define GPU_TYPES_SV

package gpu_types;

  typedef struct packed {
    logic [15:0] datapath_read_data_a;
    logic [15:0] datapath_read_data_b;
  } lane_request_t;

  typedef struct packed {
    logic [15:0] mem_addr;
    logic        mem_write_enable;
    logic        datapath_write_enable;
    logic        datapath_writeback_select;
    logic [3:0]  alu_op;
    logic [15:0] datapath_immediate;
    logic [2:0]  datapath_src_reg_a;
    logic [2:0]  datapath_src_reg_b;
    logic [2:0]  datapath_dst_reg;

  } lane_response_t;

endpackage

`endif
