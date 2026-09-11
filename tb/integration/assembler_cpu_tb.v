`include "cpu.v"

// This testbench intentionally loads program.hex from its working directory.
// tests/test_assembler.py generates that file with assembler.py before compiling
// and running this testbench.
module assembler_cpu_tb;
  reg         clk;
  reg         reset;
  reg  [15:0] memory [0:511];
  wire [15:0] mem_read_data;
  wire [ 8:0] mem_address;
  wire [15:0] mem_write_data;
  wire        mem_write_enable;
  wire        halted;
  integer     index;
  integer     cycles;

  cpu dut (
      .clk             (clk),
      .reset           (reset),
      .mem_read_data   (mem_read_data),
      .mem_address     (mem_address),
      .mem_write_data  (mem_write_data),
      .mem_write_enable(mem_write_enable),
      .halted          (halted)
  );

  assign mem_read_data = memory[mem_address];

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (mem_write_enable)
      memory[mem_address] <= mem_write_data;
  end

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    cycles = 0;

    for (index = 0; index < 512; index = index + 1)
      memory[index] = 16'b0;

    $readmemh("program.hex", memory);

    // Reset the PC, instruction register, and register file before fetching
    // the assembler-generated program.
    repeat (2) @(posedge clk);
    reset = 1'b0;

    while (!halted && cycles < 100) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    #1;

    if (!halted)
      $fatal(1, "assembler program did not halt within %0d cycles", cycles);

    // ldi r1 7; ldi r2 5; add r3 r1 r2; ldi r4 20; store r3 r4;
    // load r5 r4; ldi r6 21; store r5 r6; halt
    if (memory[20] !== 16'd12)
      $fatal(1, "assembled program stored %0d at address 20; expected 12", memory[20]);

    if (memory[21] !== 16'd12)
      $fatal(1, "assembled program loaded/stored %0d at address 21; expected 12", memory[21]);

    $display("assembler_cpu_tb passed");
    $finish;
  end
endmodule
