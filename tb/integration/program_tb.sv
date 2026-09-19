`include "cpu.sv"

// Generic runner for any assembled program.
//
// Assemble a source file first (for example, `python3 assembler.py foo.asm`),
// then run this testbench with `just test program_tb`.  By default it loads
// program.hex from the working directory.  These optional VVP plusargs are
// also supported:
//
//   +PROGRAM=path/to/program.hex
//   +TIMEOUT=10000
//   +VCD=build/sim/program.vcd
//
// It intentionally contains no program-specific input data or assertions.
module program_tb;
  logic            clk;
  logic            reset;
  logic     [15:0] memory           [0:511];
  wire    [15:0] mem_read_data;
  wire cpu_types_pkg::cpu_mem_request_t mem_request;
  wire           halted;
  integer        index;
  integer        cycles;
  integer        max_cycles;
  integer        program_handle;
  integer        scan_result;
  logic     [15:0] program_word;
  string         program_file;
  string         program_line;
  string         waveform_file;

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
    max_cycles = 10000;
    program_file = "program.hex";

    if ($value$plusargs("PROGRAM=%s", program_file))
      $display("Using program path supplied by +PROGRAM.");
    if ($value$plusargs("TIMEOUT=%d", max_cycles)) $display("Using timeout supplied by +TIMEOUT.");

    if ($value$plusargs("VCD=%s", waveform_file)) begin
      $dumpfile(waveform_file);
      $dumpvars(0, program_tb);
    end

    for (index = 0; index < 512; index = index + 1) memory[index] = 16'b0;

    program_handle = $fopen(program_file, "r");
    if (program_handle == 0) $fatal(1, "could not open program file: %s", program_file);

    // Load one hex word per line, without asking $readmemh to fill the
    // remainder of RAM (which otherwise produces a warning for short files).
    index = 0;
    while ($fgets(
        program_line, program_handle
    )) begin
      if (index >= 512) $fatal(1, "program exceeds the 512-word RAM: %s", program_file);

      scan_result = $sscanf(program_line, "%h", program_word);
      if (scan_result != 1) $fatal(1, "invalid hex word in program file: %s", program_file);

      memory[index] = program_word;
      index = index + 1;
    end
    $fclose(program_handle);
    $display("Loaded %0d program words from %s.", index, program_file);

    // Reset the PC, instruction register, and register files before fetch.
    repeat (2) @(posedge clk);
    reset = 1'b0;

    while (!halted && cycles < max_cycles) begin
      @(posedge clk);
      cycles = cycles + 1;
    end
    #1;

    if (!halted) $fatal(1, "program did not halt within %0d cycles", max_cycles);

    $display("Program halted after %0d cycles.", cycles);
    for (index = 0; index < 8; index = index + 1)
    $display(
        "r%0d = 0x%04h (%0d)",
        index + 1,
        dut.datapath.registers.data_out[index],
        dut.datapath.registers.data_out[index]
    );
    $finish;
  end
endmodule
