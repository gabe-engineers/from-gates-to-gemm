`include "fsm_states.svh"
`include "cpu_types.svh"
`include "control_unit.sv"
`include "datapath.sv"
`include "control_helpers.svh"
`include "gpu_types.svh"

module cpu (
    input  wire                            clk,
    input  wire                            reset,
    input  wire                     [15:0] mem_read_data,
    input  gpu_types::gpu_state_t           gpu_state,
    output wire cpu_types_pkg::cpu_mem_request_t mem_request,
    output wire                            halted,
    output gpu_types::gpu_dispatch_t        gpu_dispatch
);

  wire cpu_types_pkg::control_unit_out_t control_out;

  cpu_types_pkg::scalar_request_t      scalar_request;
  cpu_types_pkg::scalar_response_t     scalar_response;
  cpu_types_pkg::vector_mem_request_t  vector_mem_request;
  cpu_types_pkg::vector_mem_response_t vector_mem_response;
  cpu_types_pkg::vector_alu_request_t  vector_alu_request;

  assign scalar_request.write_enable     = control_out.datapath_write_enable;
  assign scalar_request.writeback_source = control_out.datapath_writeback_source;
  assign scalar_request.thread_id        = 3'd0;
  assign scalar_request.alu_op           = control_out.alu_op;
  assign scalar_request.immediate        = control_out.datapath_immediate;
  assign scalar_request.read_addr_a      = control_out.datapath_src_reg_a;
  assign scalar_request.read_addr_b      = control_out.datapath_src_reg_b;
  assign scalar_request.write_addr       = control_out.datapath_dst_reg;

  assign vector_mem_request.write_enable = control_out.vector_write_enable;
  assign vector_mem_request.write_addr   = control_out.vector_write_addr;
  assign vector_mem_request.write_lane   = control_out.vector_write_lane;
  assign vector_mem_request.write_data   = control_out.vector_write_data;
  assign vector_mem_request.read_addr    = control_out.vector_read_addr;
  assign vector_mem_request.read_lane    = control_out.vector_read_lane;

  assign vector_alu_request.write_enable         = control_out.vector_alu_write_enable;
  assign vector_alu_request.write_addr           = control_out.vector_alu_write_addr;
  assign vector_alu_request.operation            = control_out.vector_alu_operation;
  assign vector_alu_request.read_addr_a          = control_out.vector_alu_read_addr_a;
  assign vector_alu_request.read_addr_b          = control_out.vector_alu_read_addr_b;
  assign vector_alu_request.dot_writeback_select = control_out.datapath_vector_dot_writeback_select;

  // STORE takes its value from scalar source operand A; VST takes the
  // matching lane from its vector source. Assembly syntax places the address
  // first, while the decoder routes it to scalar source operand B internally.
  assign mem_request.address = control_out.mem_addr;
  assign mem_request.write_enable = control_out.mem_write_enable;
  assign mem_request.write_data =
      control_out.vector_store_active ? vector_mem_response.read_data : scalar_response.read_data_a;
  assign gpu_dispatch.command = gpu_types::gpu_command_t'(control_out.gpu_command);
  assign gpu_dispatch.launch_address = control_out.gpu_launch_address;
  assign halted = control_out.halted;

  control_unit control_unit_module (
      // Inputs:
      .clk                 (clk),
      .reset               (reset),
      .mem_read_data       (mem_read_data),
      .datapath_read_data_a(scalar_response.read_data_a),
      .datapath_read_data_b(scalar_response.read_data_b),
      .datapath_zero_flag  (scalar_response.zero_flag),
      .datapath_less_than_flag(scalar_response.less_than_flag),
      .gpu_state           (gpu_state),
      .out                 (control_out)
  );

  datapath_16bit datapath (
      .clk               (clk),
      .reset             (reset),
      .scalar_request    (scalar_request),
      .scalar_response   (scalar_response),
      .vector_mem_request(vector_mem_request),
      .vector_mem_response(vector_mem_response),
      .vector_alu_request(vector_alu_request)
  );

endmodule
