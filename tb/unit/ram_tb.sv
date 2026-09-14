`include "ram.sv"

module memory_tb;

  logic        clk;
  logic [15:0] cpu_address;
  logic        cpu_write_enable;
  logic [15:0] cpu_write_data;
  logic [15:0] gpu_address;
  logic        gpu_write_enable;
  logic [15:0] gpu_write_data;
  wire [15:0] cpu_read_data;
  wire [15:0] gpu_read_data;

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
      clk = 0;
      #10;
      clk = 1;
      #10;
    end
  endtask

  task expect_read_data(input [15:0] expected_cpu_read_data, input [15:0] expected_gpu_read_data);
    begin
      if (cpu_read_data !== expected_cpu_read_data || gpu_read_data !== expected_gpu_read_data)
        $fatal(1,
            "Unexpected RAM data: cpu=%h (expected %h), gpu=%h (expected %h)",
            cpu_read_data, expected_cpu_read_data, gpu_read_data, expected_gpu_read_data);
    end
  endtask

  initial begin
    clk = 0;
    cpu_address = 0;
    cpu_write_enable = 0;
    cpu_write_data = 0;
    gpu_address = 0;
    gpu_write_enable = 0;
    gpu_write_data = 0;

    // CPU and GPU can write different words on the same edge.
    cpu_address = 16'd42;
    cpu_write_enable = 1;
    cpu_write_data = 16'hA5A5;
    gpu_address = 16'd43;
    gpu_write_enable = 1;
    gpu_write_data = 16'h5A5A;
    tick;
    expect_read_data(16'hA5A5, 16'h5A5A);

    // The ports can read independent addresses at the same time.
    cpu_write_enable = 0;
    gpu_write_enable = 0;
    cpu_address = 16'd43;
    gpu_address = 16'd42;
    #1;
    expect_read_data(16'h5A5A, 16'hA5A5);

    // CPU has deterministic priority for a same-address write collision.
    cpu_address = 16'd100;
    cpu_write_enable = 1;
    cpu_write_data = 16'hC0DE;
    gpu_address = 16'd100;
    gpu_write_enable = 1;
    gpu_write_data = 16'hFACE;
    tick;
    expect_read_data(16'hC0DE, 16'hC0DE);

    $finish;
  end

endmodule
