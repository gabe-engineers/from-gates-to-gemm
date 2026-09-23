`include "register.sv"
`include "control_fsm.sv"
`include "register_file.sv"
`include "alu.sv"
`include "warp.sv"

module warp_tb;
  logic clk;
  logic reset;
  logic start;
  logic [15:0] start_address;
  logic enable;
  wire gpu_types::warp_mem_response_t mem_response;
  wire [7:0][15:0] mem_read_data;
  logic [15:0] instruction_memory [0:511];
  wire halted;
  wire gpu_types::warp_mem_request_t warp_mem_request;

  for (genvar lane = 0; lane < 8; lane++) begin : instruction_read_ports
    assign mem_read_data[lane] = instruction_memory[warp_mem_request.address[lane]];
  end
  assign mem_response.read_data = mem_read_data;

  warp dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .start_address(start_address),
      .enable(enable),
      .mem_response(mem_response),
      .halted(halted),
      .warp_mem_request(warp_mem_request)
  );

  task tick;
    begin
      clk = 1'b0;
      #5;
      clk = 1'b1;
      #5;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    start = 1'b0;
    start_address = 16'd23;
    enable = 1'b0;
    for (int index = 0; index < 512; index++)
      instruction_memory[index] = {`OP_HALT, 11'd0};
    instruction_memory[23] = {`OP_TID, 3'd3, 8'd0};
    instruction_memory[24] = {`OP_HALT, 11'd0};
    instruction_memory[100] = {`OP_TID, 3'd4, 8'd0};
    tick;

    reset = 1'b0;
    tick;
    if (dut.control_unit_module.fsm_out_state !== `FSM_FETCH_DECODE)
      $fatal(1, "disabled warp advanced before start");
    if (halted)
      $fatal(1, "disabled warp unexpectedly halted");
    if (warp_mem_request.write_enable || warp_mem_request.address[0] !== 16'd0)
      $fatal(1, "disabled warp issued an unexpected memory request");

    // A launch-style start resets the warp; subsequent enable cycles execute
    // the same scalar/SIMT instruction across every lane.
    start = 1'b1;
    tick;
    start = 1'b0;
    if (warp_mem_request.address[0] !== 16'd23)
      $fatal(1, "warp did not begin fetching from start_address");
    enable = 1'b1;
    tick;
    if (dut.datapath_module.lane_responses[0] !== 16'd0 ||
        dut.datapath_module.lane_responses[7] !== 16'd7)
      $fatal(1, "TID was not broadcast with per-lane IDs");
    tick;
    if (warp_mem_request.address[0] !== 16'd24)
      $fatal(1, "warp did not advance its instruction address");

    // HALT completes the warp. A subsequent start clears halted state.
    tick;
    tick;
    if (!halted)
      $fatal(1, "warp did not halt on HALT");

    start_address = 16'd100;
    start = 1'b1;
    tick;
    start = 1'b0;
    if (halted)
      $fatal(1, "start did not clear the completed warp state");
    if (warp_mem_request.address[0] !== 16'd100)
      $fatal(1, "restart did not install a new instruction address");

    $display("warp_tb passed");
    $finish;
  end
endmodule
