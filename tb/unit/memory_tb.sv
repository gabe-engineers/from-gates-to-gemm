`include "memory.sv"

module memory_tb;

  localparam int GPU_LANES = 8;

  logic        clk;
  cpu_types_pkg::cpu_mem_request_t cpu_mem_request;
  logic        gpu_write_enable;
  logic [127:0] gpu_mem_address;
  logic [127:0] gpu_mem_write_data;
  wire gpu_types::warp_mem_request_t gpu_mem_request;
  wire [15:0] cpu_read_data;
  wire gpu_types::warp_mem_response_t gpu_read_response;
  wire [7:0][15:0] gpu_read_data = gpu_read_response.read_data;

  memory dut (
      .clk              (clk),
      .cpu_mem_request  (cpu_mem_request),
      .cpu_read_data    (cpu_read_data),
      .gpu_mem_request  (gpu_mem_request),
      .gpu_read_response(gpu_read_response)
  );

  assign gpu_mem_request.write_enable = gpu_write_enable;
  assign gpu_mem_request.address = gpu_mem_address;
  assign gpu_mem_request.write_data = gpu_mem_write_data;

  task tick;
    begin
      clk = 1'b0;
      #10;
      clk = 1'b1;
      #10;
    end
  endtask

  task expect_cpu_read(input [15:0] expected_data);
    begin
      if (cpu_read_data !== expected_data)
        $fatal(1, "CPU read: got %h, expected %h", cpu_read_data, expected_data);
    end
  endtask

  task expect_gpu_read(input integer lane, input [15:0] expected_data);
    begin
      if (gpu_read_data[lane] !== expected_data)
        $fatal(1, "GPU lane %0d read: got %h, expected %h", lane,
               gpu_read_data[lane], expected_data);
    end
  endtask

  initial begin
    clk = 1'b0;
    cpu_mem_request = '0;
    gpu_write_enable = 1'b0;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_mem_address[lane * 16 +: 16] = 16'd0;
      gpu_mem_write_data[lane * 16 +: 16] = 16'd0;
    end

    // Registers initialize to zero, and every GPU lane can read independently.
    #1;
    expect_cpu_read(16'd0);
    for (int lane = 0; lane < GPU_LANES; lane++) expect_gpu_read(lane, 16'd0);

    // CPU and all eight GPU lanes can write distinct words on the same edge.
    cpu_mem_request.address = 16'd42;
    cpu_mem_request.write_enable = 1'b1;
    cpu_mem_request.write_data = 16'hA5A5;
    gpu_write_enable = 1'b1;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_mem_address[lane * 16 +: 16] = 16'd80 + lane;
      gpu_mem_write_data[lane * 16 +: 16] = 16'h1000 + lane;
    end
    tick;
    expect_cpu_read(16'hA5A5);
    for (int lane = 0; lane < GPU_LANES; lane++)
      expect_gpu_read(lane, 16'h1000 + lane);

    // The CPU and GPU ports can read unrelated words at the same time.
    cpu_mem_request.write_enable = 1'b0;
    gpu_write_enable = 1'b0;
    cpu_mem_request.address = 16'd87;
    for (int lane = 0; lane < GPU_LANES; lane++)
      gpu_mem_address[lane * 16 +: 16] = 16'd87 - lane;
    #1;
    expect_cpu_read(16'h1007);
    for (int lane = 0; lane < GPU_LANES; lane++)
      expect_gpu_read(lane, 16'h1007 - lane);

    // A disabled warp store leaves every lane's target word unchanged.
    cpu_mem_request.address = 16'd200;
    gpu_write_enable = 1'b0;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_mem_address[lane * 16 +: 16] = 16'd200 + lane;
      gpu_mem_write_data[lane * 16 +: 16] = 16'h2000 + lane;
    end
    tick;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      expect_gpu_read(lane, 16'd0);
    end

    // An enabled warp store writes each lane's independent request.
    gpu_write_enable = 1'b1;
    tick;
    for (int lane = 0; lane < GPU_LANES; lane++) expect_gpu_read(lane, 16'h2000 + lane);

    // A CPU write wins when it collides with any enabled GPU lane.
    cpu_mem_request.address = 16'd300;
    cpu_mem_request.write_enable = 1'b1;
    cpu_mem_request.write_data = 16'hC0DE;
    gpu_write_enable = 1'b1;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_mem_address[lane * 16 +: 16] = 16'd320 + lane;
      gpu_mem_write_data[lane * 16 +: 16] = 16'h3000 + lane;
    end
    gpu_mem_address[3 * 16 +: 16] = 16'd300;
    gpu_mem_write_data[3 * 16 +: 16] = 16'hFACE;
    tick;
    expect_cpu_read(16'hC0DE);
    expect_gpu_read(3, 16'hC0DE);
    expect_gpu_read(0, 16'h3000);
    expect_gpu_read(7, 16'h3007);

    $finish;
  end

endmodule
