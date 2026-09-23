`include "register.sv"
`include "control_fsm.sv"
`include "register_file.sv"
`include "alu.sv"
`include "warp.sv"

module warp_memory_tb;
  logic clk;
  logic reset;
  logic start;
  logic [15:0] start_address;
  logic enable;
  logic [15:0] memory [0:511];
  wire [7:0][15:0] mem_read_data;
  wire gpu_types::gpu_mem_response_t mem_response;
  wire halted;
  wire gpu_types::warp_mem_request_t warp_mem_request;
  wire [15:0] lane_result [0:7];

  for (genvar lane = 0; lane < 8; lane++) begin : read_ports
    assign mem_read_data[lane] = memory[warp_mem_request.address[lane]];
  end
  assign mem_response.read_data = mem_read_data;

  for (genvar lane = 0; lane < 8; lane++) begin : write_ports
    always @(posedge clk)
      if (warp_mem_request.write_enable)
        memory[warp_mem_request.address[lane]] <= warp_mem_request.write_data[lane];
  end

  for (genvar lane = 0; lane < 8; lane++) begin : observe
    assign lane_result[lane] =
        dut.datapath_module.warp_lanes[lane].lane_module.reg_file.data_out[4];
  end

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
    start_address = 16'd0;
    enable = 1'b0;
    for (int index = 0; index < 512; index++) memory[index] = 16'b0;
    memory[0] = {`OP_LDI, 3'd1, 8'h2A};
    memory[1] = {`OP_LDI, 3'd2, 8'd5};
    memory[2] = {`OP_STORE, 3'd2, 3'd1, 5'd0};
    memory[3] = {`OP_LOAD, 3'd4, 3'd2, 5'd0};
    memory[4] = {`OP_HALT, 11'd0};
    tick;

    reset = 1'b0;
    tick;
    start = 1'b1;
    tick;
    start = 1'b0;
    enable = 1'b1;

    for (int cycle = 0; cycle < 40 && !halted; cycle++) tick;
    #1;

    if (!halted)
      $fatal(1, "warp did not halt");
    if (memory[5] !== 16'h002A)
      $fatal(1, "STORE did not write memory[5]: got %h", memory[5]);
    for (int lane = 0; lane < 8; lane++)
      if (lane_result[lane] !== 16'h002A)
        $fatal(1, "lane %0d LOAD produced %h", lane, lane_result[lane]);

    $display("warp_memory_tb passed");
    $finish;
  end
endmodule
