`include "vector_register_file.sv"

module vector_register_file_tb;
  logic         clk;
  logic         reset;
  logic         write_enable;
  logic  [ 2:0] write_addr;
  logic  [ 2:0] write_lane;
  logic  [15:0] write_data;
  logic  [ 2:0] read_addr;
  logic  [ 2:0] read_lane;
  wire [15:0] read_data;
  logic         vector_alu_write_enable;
  logic  [ 2:0] vector_alu_write_addr;
  logic  [127:0] vector_alu_write_data;
  logic  [ 2:0] vector_alu_read_addr_a;
  logic  [ 2:0] vector_alu_read_addr_b;
  wire [127:0] vector_alu_read_data_a;
  wire [127:0] vector_alu_read_data_b;

  vector_register_file dut (
      .clk         (clk),
      .reset       (reset),
      .write_enable(write_enable),
      .write_addr  (write_addr),
      .write_lane  (write_lane),
      .write_data  (write_data),
      .read_addr   (read_addr),
      .read_lane   (read_lane),
      .read_data   (read_data),
      .vector_alu_write_enable(vector_alu_write_enable),
      .vector_alu_write_addr  (vector_alu_write_addr),
      .vector_alu_write_data  (vector_alu_write_data),
      .vector_alu_read_addr_a (vector_alu_read_addr_a),
      .vector_alu_read_addr_b (vector_alu_read_addr_b),
      .vector_alu_read_data_a (vector_alu_read_data_a),
      .vector_alu_read_data_b (vector_alu_read_data_b)
  );

  task tick;
    begin
      clk = 1'b0;
      #10;
      clk = 1'b1;
      #10;
    end
  endtask

  task expect_lane(input [2:0] expected_addr, input [2:0] expected_lane,
                   input [15:0] expected_data);
    begin
      read_addr = expected_addr;
      read_lane = expected_lane;
      #1;
      if (read_data !== expected_data)
        $fatal(1, "v%0d lane %0d: got %h, expected %h", expected_addr + 1,
               expected_lane, read_data, expected_data);
    end
  endtask

  initial begin
    reset = 1'b1;
    write_enable = 1'b0;
    write_addr = 3'd0;
    write_lane = 3'd0;
    write_data = 16'd0;
    read_addr = 3'd0;
    read_lane = 3'd0;
    vector_alu_write_enable = 1'b0;
    vector_alu_write_addr = 3'd0;
    vector_alu_write_data = 128'd0;
    vector_alu_read_addr_a = 3'd0;
    vector_alu_read_addr_b = 3'd0;
    tick;

    reset = 1'b0;
    expect_lane(3'd0, 3'd0, 16'd0);
    expect_lane(3'd7, 3'd7, 16'd0);

    write_enable = 1'b1;
    write_addr = 3'd0;
    write_lane = 3'd0;
    write_data = 16'h1111;
    tick;

    write_addr = 3'd0;
    write_lane = 3'd7;
    write_data = 16'h7777;
    tick;

    write_addr = 3'd1;
    write_lane = 3'd0;
    write_data = 16'h2222;
    tick;

    expect_lane(3'd0, 3'd0, 16'h1111);
    expect_lane(3'd0, 3'd7, 16'h7777);
    expect_lane(3'd1, 3'd0, 16'h2222);
    expect_lane(3'd1, 3'd7, 16'd0);

    write_enable = 1'b0;
    write_addr = 3'd0;
    write_lane = 3'd0;
    write_data = 16'hFFFF;
    tick;
    expect_lane(3'd0, 3'd0, 16'h1111);

    // A vector ALU write updates all eight lanes of the selected vector register.
    vector_alu_write_enable = 1'b1;
    vector_alu_write_addr = 3'd2;
    vector_alu_write_data = 128'h0008_0007_0006_0005_0004_0003_0002_0001;
    tick;
    vector_alu_write_enable = 1'b0;
    expect_lane(3'd2, 3'd0, 16'h0001);
    expect_lane(3'd2, 3'd3, 16'h0004);
    expect_lane(3'd2, 3'd7, 16'h0008);
    expect_lane(3'd0, 3'd0, 16'h1111);

    vector_alu_read_addr_a = 3'd2;
    vector_alu_read_addr_b = 3'd0;
    #1;
    if (vector_alu_read_data_a[15:0] !== 16'h0001 ||
        vector_alu_read_data_a[127:112] !== 16'h0008 ||
        vector_alu_read_data_b[15:0] !== 16'h1111)
      $fatal(1, "vector ALU read ports did not return the selected vectors");

    reset = 1'b1;
    tick;
    expect_lane(3'd0, 3'd0, 16'd0);
    expect_lane(3'd0, 3'd7, 16'd0);
    expect_lane(3'd1, 3'd0, 16'd0);

    $finish;
  end
endmodule
