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
  wire [15:0] datapath_read_data_a;
  wire [15:0] datapath_read_data_b;
  wire [15:0] vector_read_data;

  // STORE takes its value from scalar source operand A; VST takes the
  // matching lane from its vector source. Assembly syntax places the address
  // first, while the decoder routes it to scalar source operand B internally.
  assign mem_request.address = control_out.mem_addr;
  assign mem_request.write_enable = control_out.mem_write_enable;
  assign mem_request.write_data =
      control_out.vector_store_active ? vector_read_data : datapath_read_data_a;
  assign gpu_dispatch.command = gpu_types::gpu_command_t'(control_out.gpu_command);
  assign gpu_dispatch.launch_address = control_out.gpu_launch_address;
  assign halted = control_out.halted;

  control_unit control_unit_module (
      // Inputs:
      .clk                 (clk),
      .reset               (reset),
      .mem_read_data       (mem_read_data),
      .datapath_read_data_a(datapath_read_data_a),
      .datapath_read_data_b(datapath_read_data_b),
      .gpu_state           (gpu_state),
      .out                 (control_out)
  );

  datapath_16bit datapath (
      .clk(clk),
      .reset(reset),
      .write_enable(control_out.datapath_write_enable),
      .writeback_source(control_out.datapath_writeback_source),
      .thread_id(3'd0),
      .alu_op(control_out.alu_op),
      .immediate(control_out.datapath_immediate),
      .read_addr_a(control_out.datapath_src_reg_a),
      .read_addr_b(control_out.datapath_src_reg_b),
      .write_addr(control_out.datapath_dst_reg),
      .write_reg_data(),
      .read_data_a(datapath_read_data_a),
      .read_data_b(datapath_read_data_b),
      .vector_write_enable(control_out.vector_write_enable),
      .vector_write_addr  (control_out.vector_write_addr),
      .vector_write_lane  (control_out.vector_write_lane),
      .vector_write_data  (control_out.vector_write_data),
      .vector_read_addr   (control_out.vector_read_addr),
      .vector_read_lane   (control_out.vector_read_lane),
      .vector_read_data   (vector_read_data),
      .vector_alu_write_enable(control_out.vector_alu_write_enable),
      .vector_alu_write_addr  (control_out.vector_alu_write_addr),
      .vector_alu_operation   (control_out.vector_alu_operation),
      .vector_alu_read_addr_a (control_out.vector_alu_read_addr_a),
      .vector_alu_read_addr_b (control_out.vector_alu_read_addr_b),
      .vector_dot_writeback_select(control_out.datapath_vector_dot_writeback_select)
  );

endmodule
