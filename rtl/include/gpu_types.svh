`ifndef GPU_TYPES_SVH
`define GPU_TYPES_SVH

package gpu_types;

  typedef enum logic {
    GPU_COMMAND_NONE   = 1'b0,
    GPU_COMMAND_LAUNCH = 1'b1
  } gpu_command_t;

  typedef struct packed {
    gpu_command_t command;
    logic [15:0]  launch_address;
  } gpu_dispatch_t;

  typedef enum logic {
    GPU_STATE_IDLE    = 1'b0,
    GPU_STATE_RUNNING = 1'b1
  } gpu_state_t;

  typedef struct packed {
    logic        valid;
    logic [4:0]  opcode;
    logic [2:0]  dst_reg;
    logic [2:0]  src_reg_a;
    logic [2:0]  src_reg_b;
    logic [15:0] immediate;
    logic [15:0] address;
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
  } warp_request_t;

  typedef struct packed {
    logic [15:0] value;
    logic        operands_equal;
    logic [15:0] mem_address;
    logic [15:0] mem_write_data;
  } warp_lane_response_t;

  typedef struct packed {
    logic [7:0][15:0] address;
    logic [7:0][15:0] write_data;
    logic             write_enable;
  } gpu_mem_request_t;

  typedef struct packed {
    logic [7:0][15:0] read_data;
  } gpu_mem_response_t;

  typedef gpu_mem_request_t warp_mem_request_t;
  typedef gpu_mem_response_t warp_mem_response_t;

  typedef struct packed {
    logic operands_equal;
    logic diverged;
  } warp_lane_status_t;

  typedef struct packed {
    logic [15:0]   instruction_address;
    logic          halted;
    logic          mem_access;
    logic          mem_write_enable;
    warp_request_t warp_request;
  } warp_control_unit_out_t;

endpackage

`endif
