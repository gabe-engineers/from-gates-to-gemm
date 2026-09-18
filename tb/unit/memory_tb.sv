`include "memory.sv"

module memory_tb;

  localparam int GPU_LANES = 8;

  logic        clk;
  logic [15:0] cpu_address;
  logic        cpu_write_enable;
  logic [15:0] cpu_write_data;
  logic [15:0] gpu_address [7:0];
  logic [ 7:0] gpu_write_enable;
  logic [15:0] gpu_write_data [7:0];
  wire [15:0] cpu_read_data;
  wire [15:0] gpu_read_data [7:0];

  memory dut (
      .clk             (clk),
      .cpu_address     (cpu_address),
      .cpu_write_enable(cpu_write_enable),
      .cpu_write_data  (cpu_write_data),
      .cpu_read_data   (cpu_read_data),
      .gpu_address     (gpu_address),
      .gpu_write_enable(gpu_write_enable),
      .gpu_write_data  (gpu_write_data),
      .gpu_read_data   (gpu_read_data)
  );

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
    cpu_address = 16'd0;
    cpu_write_enable = 1'b0;
    cpu_write_data = 16'd0;
    gpu_write_enable = 8'd0;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_address[lane] = 16'd0;
      gpu_write_data[lane] = 16'd0;
    end

    // Registers initialize to zero, and every GPU lane can read independently.
    #1;
    expect_cpu_read(16'd0);
    for (int lane = 0; lane < GPU_LANES; lane++) expect_gpu_read(lane, 16'd0);

    // CPU and all eight GPU lanes can write distinct words on the same edge.
    cpu_address = 16'd42;
    cpu_write_enable = 1'b1;
    cpu_write_data = 16'hA5A5;
    gpu_write_enable = 8'hFF;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_address[lane] = 16'd80 + lane;
      gpu_write_data[lane] = 16'h1000 + lane;
    end
    tick;
    expect_cpu_read(16'hA5A5);
    for (int lane = 0; lane < GPU_LANES; lane++)
      expect_gpu_read(lane, 16'h1000 + lane);

    // The CPU and GPU ports can read unrelated words at the same time.
    cpu_write_enable = 1'b0;
    gpu_write_enable = 8'd0;
    cpu_address = 16'd87;
    for (int lane = 0; lane < GPU_LANES; lane++) gpu_address[lane] = 16'd80 + (7 - lane);
    #1;
    expect_cpu_read(16'h1007);
    for (int lane = 0; lane < GPU_LANES; lane++)
      expect_gpu_read(lane, 16'h1007 - lane);

    // Each GPU write-enable bit controls only its corresponding lane.
    cpu_address = 16'd200;
    gpu_write_enable = 8'b10001001;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_address[lane] = 16'd200 + lane;
      gpu_write_data[lane] = 16'h2000 + lane;
    end
    tick;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      if (lane == 0 || lane == 3 || lane == 7)
        expect_gpu_read(lane, 16'h2000 + lane);
      else
        expect_gpu_read(lane, 16'd0);
    end

    // A CPU write wins when it collides with any enabled GPU lane.
    cpu_address = 16'd300;
    cpu_write_enable = 1'b1;
    cpu_write_data = 16'hC0DE;
    gpu_write_enable = 8'hFF;
    for (int lane = 0; lane < GPU_LANES; lane++) begin
      gpu_address[lane] = 16'd320 + lane;
      gpu_write_data[lane] = 16'h3000 + lane;
    end
    gpu_address[3] = 16'd300;
    gpu_write_data[3] = 16'hFACE;
    tick;
    expect_cpu_read(16'hC0DE);
    expect_gpu_read(3, 16'hC0DE);
    expect_gpu_read(0, 16'h3000);
    expect_gpu_read(7, 16'h3007);

    $finish;
  end

endmodule
