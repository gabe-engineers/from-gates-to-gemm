`ifndef GPU_TYPES_SVH
`define GPU_TYPES_SVH

package gpu_types;

  // Commands emitted by the scalar decoder to coordinate GPU work.
  typedef enum logic [1:0] {
    GPU_COMMAND_NONE   = 2'b00,
    GPU_COMMAND_LAUNCH = 2'b01
  } gpu_command_t;

  typedef enum logic {
    GPU_STATE_IDLE    = 1'b0,
    GPU_STATE_RUNNING = 1'b1
  } gpu_state_t;

  // The scalar/SIMT instruction subset understood by a warp. The opcode
  // preserves the shared ISA encoding, while valid distinguishes unsupported
  // CPU-only instructions from supported no-operand instructions such as HALT.
  typedef struct packed {
    logic        valid;
    logic [ 4:0] opcode;
    logic [ 2:0] dst_reg;
    logic [ 2:0] src_reg_a;
    logic [ 2:0] src_reg_b;
    logic [15:0] immediate;
  } warp_decoder_out_t;

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
    logic write_enable;
    // Each field contains one 16-bit word per lane; index 0 is lane 0.
    logic [7:0][15:0] mem_address;
    logic [7:0][15:0] mem_write_data;
  } warp_mem_request;

endpackage

`endif
