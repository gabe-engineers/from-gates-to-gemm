`include "cpu.sv"

// This testbench intentionally loads program.hex from its working directory.
// tests/test_assembler.py generates that file with assembler.py before compiling
// and running this testbench.
module assembler_cpu_tb;
  logic         clk;
  logic         reset;
  logic  [15:0] memory [0:511];
  wire [15:0] mem_read_data;
  wire cpu_types_pkg::cpu_mem_request_t mem_request;
  wire        halted;
  integer     index;
  integer     cycles;

  cpu dut (
      .clk             (clk),
      .reset           (reset),
      .mem_read_data   (mem_read_data),
      .mem_request     (mem_request),
      .halted          (halted)
  );

  assign mem_read_data = memory[mem_request.address];

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (mem_request.write_enable)
      memory[mem_request.address] <= mem_request.write_data;
  end

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    cycles = 0;

    for (index = 0; index < 512; index = index + 1)
      memory[index] = 16'b0;

    $readmemh("program.hex", memory);

    memory[100] = 16'd10;
    memory[101] = 16'd20;
    memory[102] = 16'd30;
    memory[103] = 16'd40;
    memory[104] = 16'd50;
    memory[105] = 16'd60;
    memory[106] = 16'd70;
    memory[107] = 16'd80;
    memory[110] = 16'd1;
    memory[111] = 16'd2;
    memory[112] = 16'd3;
    memory[113] = 16'd4;
    memory[114] = 16'd5;
    memory[115] = 16'd6;
    memory[116] = 16'd7;
    memory[117] = 16'd8;

    // Reset the PC, instruction register, and register file before fetching
    // the assembler-generated program.
    repeat (2) @(posedge clk);
    reset = 1'b0;

    while (!halted && cycles < 200) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    #1;

    if (!halted)
      $fatal(1, "assembler program did not halt within %0d cycles", cycles);

    // The assembler test builds addresses above 255 with LUI and OR,
    // then exercises scalar memory, all vector operations, and HALT.
    if (memory[400] !== 16'd12)
      $fatal(1, "assembled program stored %0d at address 400; expected 12", memory[400]);

    if (memory[401] !== 16'd12)
      $fatal(1, "assembled program loaded/stored %0d at address 401; expected 12", memory[401]);

    if (memory[402] !== 16'd7)
      $fatal(1, "VLD unexpectedly changed scalar r1 to %0d", memory[402]);

    if (memory[403] !== 16'd2040)
      $fatal(1, "VDOT stored %0d at address 403; expected 2040", memory[403]);

    if (memory[200] !== 16'd10 || memory[201] !== 16'd20 ||
        memory[202] !== 16'd30 || memory[203] !== 16'd40 ||
        memory[204] !== 16'd50 || memory[205] !== 16'd60 ||
        memory[206] !== 16'd70 || memory[207] !== 16'd80)
      $fatal(1, "VLD/VST lanes: %0d %0d %0d %0d %0d %0d %0d %0d",
             memory[200], memory[201], memory[202], memory[203],
             memory[204], memory[205], memory[206], memory[207]);

    if (memory[300] !== 16'd11 || memory[301] !== 16'd22 ||
        memory[302] !== 16'd33 || memory[303] !== 16'd44 ||
        memory[304] !== 16'd55 || memory[305] !== 16'd66 ||
        memory[306] !== 16'd77 || memory[307] !== 16'd88)
      $fatal(1, "VADD did not write the expected lanes");

    if (memory[310] !== 16'd9 || memory[311] !== 16'd18 ||
        memory[312] !== 16'd27 || memory[313] !== 16'd36 ||
        memory[314] !== 16'd45 || memory[315] !== 16'd54 ||
        memory[316] !== 16'd63 || memory[317] !== 16'd72)
      $fatal(1, "VSUB did not write the expected lanes");

    if (memory[320] !== 16'd10 || memory[321] !== 16'd40 ||
        memory[322] !== 16'd90 || memory[323] !== 16'd160 ||
        memory[324] !== 16'd250 || memory[325] !== 16'd360 ||
        memory[326] !== 16'd490 || memory[327] !== 16'd640)
      $fatal(1, "VMUL did not write the expected lanes");

    $display("assembler_cpu_tb passed");
    $finish;
  end
endmodule
