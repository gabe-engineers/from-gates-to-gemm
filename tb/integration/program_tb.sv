`include "chip.sv"

// Generic runner for any assembled program, CPU-only or with a GPU kernel
// launched by GLAUNCH and joined by GWAIT.
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
// The image is written into the chip RAM through its program-load port while
// the CPU and GPU are held in reset.  It intentionally contains no
// program-specific input data or assertions.
module program_tb;
  logic            clk;
  logic            reset;
  logic            load_enable;
  logic     [15:0] load_address;
  logic     [15:0] load_data;
  wire             halted;
  integer          index;
  integer          cycles;
  integer          max_cycles;
  integer          program_handle;
  integer          scan_result;
  logic     [15:0] program_word;
  string           program_file;
  string           program_line;
  string           waveform_file;

  chip dut (
      .clk         (clk),
      .reset       (reset),
      .load_enable (load_enable),
      .load_address(load_address),
      .load_data   (load_data),
      .halted      (halted)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    load_enable = 1'b0;
    load_address = 16'b0;
    load_data = 16'b0;
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

    program_handle = $fopen(program_file, "r");
    if (program_handle == 0) $fatal(1, "could not open program file: %s", program_file);

    // Load one hex word per clock edge into the chip RAM. Reset is asserted
    // throughout, so neither the CPU nor the GPU touches memory while loading.
    index = 0;
    while ($fgets(program_line, program_handle)) begin
      if (index >= 512) $fatal(1, "program exceeds the 512-word RAM: %s", program_file);

      scan_result = $sscanf(program_line, "%h", program_word);
      if (scan_result != 1) $fatal(1, "invalid hex word in program file: %s", program_file);

      load_enable  = 1'b1;
      load_address = index;
      load_data    = program_word;
      @(posedge clk);
      index = index + 1;
    end
    $fclose(program_handle);
    load_enable = 1'b0;
    $display("Loaded %0d program words from %s.", index, program_file);

    // Release reset and run until the CPU halts (after any GWAIT completes).
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
        dut.cpu_module.datapath.registers.data_out[index],
        dut.cpu_module.datapath.registers.data_out[index]
    );
    $finish;
  end
endmodule
