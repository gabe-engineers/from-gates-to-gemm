`include "cpu.v"

module cpu_tb;
  reg clk;
  reg reset;
  reg [15:0] memory [0:65535];
  wire [15:0] mem_read_data;
  wire [15:0] mem_address;
  wire [15:0] mem_write_data;
  wire mem_write_enable;
  wire halted;
  integer cycles;

  cpu dut (clk, reset, mem_read_data, mem_address, mem_write_data, mem_write_enable, halted);
  assign mem_read_data = memory[mem_address];
  always #5 clk = ~clk;
  always @(posedge clk)
    if (mem_write_enable) memory[mem_address] <= mem_write_data;

  initial begin
    clk = 0;
    reset = 1;
    cycles = 0;

    // Construct 0x1234 without LUI, store/load through the full 16-bit address,
    // verify CMP/JE, verify a large shift, then jump to the maximum addr11.
    memory[0]  = {`OP_LDI, 3'd0, 8'h12};
    memory[1]  = {`OP_LDI, 3'd1, 8'd8};
    memory[2]  = {`OP_SHL, 3'd0, 3'd0, 3'd1, 2'd0};
    memory[3]  = {`OP_LDI, 3'd2, 8'h34};
    memory[4]  = {`OP_OR, 3'd0, 3'd0, 3'd2, 2'd0};
    memory[5]  = {`OP_LDI, 3'd3, 8'hAA};
    memory[6]  = {`OP_STORE, 3'd0, 3'd3, 5'd0};
    memory[7]  = {`OP_LOAD, 3'd4, 3'd0, 5'd0};
    memory[8]  = {`OP_CMP, 3'd3, 3'd4, 5'd0};
    memory[9]  = {`OP_JE, 11'd11};
    memory[10] = {`OP_HALT, 11'd0};
    memory[11] = {`OP_LDI, 3'd5, 8'd16};
    memory[12] = {`OP_SHR, 3'd6, 3'd0, 3'd5, 2'd0};
    memory[13] = {`OP_JMP, 11'h7FF};
    memory[2047] = {`OP_HALT, 11'd0};
    memory[16'h1234] = 16'd0;

    repeat (2) @(posedge clk);
    reset = 0;
    while (!halted && cycles < 100) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    #1;

    if (!halted) $fatal(1, "CPU did not halt");
    if (memory[16'h1234] !== 16'h00AA) $fatal(1, "16-bit STORE address failed");
    if (dut.datapath.registers.data_out[4] !== 16'h00AA) $fatal(1, "LOAD failed");
    if (dut.datapath.registers.data_out[6] !== 16'h0000) $fatal(1, "wide SHR failed");
    if (dut.control_unit_module.ir !== {`OP_HALT, 11'd0})
      $fatal(1, "addr11 jump did not fetch address 2047");

    // HALT must not clear or otherwise modify registers.
    repeat (3) @(posedge clk);
    #1;
    if (dut.datapath.registers.data_out[0] !== 16'h1234 ||
        dut.datapath.registers.data_out[4] !== 16'h00AA)
      $fatal(1, "HALT changed registers");

    $display("cpu_tb passed");
    $finish;
  end
endmodule
