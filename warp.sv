`include "gpu_types.svh"
`include "warp_control_unit.sv"
`include "warp_datapath.sv"

module warp (
    input clk,
    input reset,
    input start,
    input [15:0] start_address,
    input enable,
    input gpu_types::warp_mem_response_t mem_response,
    output halted,
    output gpu_types::warp_mem_request_t warp_mem_request
);

  wire gpu_types::warp_control_unit_out_t control_out;
  wire gpu_types::warp_lane_status_t lane_status;
  wire [7:0][15:0] lane_responses;
  wire [7:0][15:0] lane_mem_address;
  wire [7:0][15:0] lane_mem_write_data;
  wire warp_reset = reset || start;
  wire [15:0] reset_address = start ? start_address : 16'b0;

  warp_control_unit control_unit_module (
      .clk(clk),
      .reset(warp_reset),
      .start_address(reset_address),
      .enable(enable),
      .lane_status(lane_status),
      .mem_read_data(mem_response.read_data[0]),
      .out(control_out)
  );

  warp_datapath datapath_module (
      .clk(clk),
      .reset(warp_reset),
      .warp_request(control_out.warp_request),
      .mem_response(mem_response),
      .lane_responses(lane_responses),
      .lane_status(lane_status),
      .lane_mem_address(lane_mem_address),
      .lane_mem_write_data(lane_mem_write_data)
  );

  assign halted = control_out.halted;

  assign warp_mem_request =
      control_out.mem_access
          ? {lane_mem_address, lane_mem_write_data, control_out.mem_write_enable}
          : {{8{control_out.instruction_address}}, 128'b0, 1'b0};

endmodule
