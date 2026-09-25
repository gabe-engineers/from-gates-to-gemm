`include "cpu_types.svh"
`include "gpu_types.svh"

// Installed RAM size. Kept below 2^15 so the sign bit of an address difference
// stays meaningful for range/mask comparisons.
localparam int MEMORY_WORDS = 4096;

module memory (
    input                                            clk,
    input  cpu_types_pkg::cpu_mem_request_t           cpu_mem_request,
    input  gpu_types::warp_mem_request_t                 gpu_mem_request,
    // Program load port: one word per clock while the CPU and GPU are held in
    // reset. It has priority over both run-time write ports.
    input                                            load_enable,
    input                                     [15:0] load_address,
    input                                     [15:0] load_data,
    output                                    [15:0] cpu_read_data,
    output gpu_types::warp_mem_response_t            gpu_read_response
);
  logic [15:0] ram[0:MEMORY_WORDS-1];
  wire [7:0][15:0] gpu_read_words;

  // Access outside the installed RAM is architecturally undefined.
  assign cpu_read_data = ram[cpu_mem_request.address];

  generate
    for (genvar gpu_i = 0; gpu_i < 8; gpu_i++) begin : gpu_reads
      assign gpu_read_words[gpu_i] = ram[gpu_mem_request.address[gpu_i]];
    end
  endgenerate

  assign gpu_read_response.read_data = gpu_read_words;

  // One write port per source, resolved by priority in a single clocked block:
  // program load beats the CPU, which beats every GPU lane, and the
  // highest-numbered GPU lane wins among lanes (later nonblocking assigns win).
  always @(posedge clk) begin
    if (gpu_mem_request.write_enable) begin
      ram[gpu_mem_request.address[0]] <= gpu_mem_request.write_data[0];
      ram[gpu_mem_request.address[1]] <= gpu_mem_request.write_data[1];
      ram[gpu_mem_request.address[2]] <= gpu_mem_request.write_data[2];
      ram[gpu_mem_request.address[3]] <= gpu_mem_request.write_data[3];
      ram[gpu_mem_request.address[4]] <= gpu_mem_request.write_data[4];
      ram[gpu_mem_request.address[5]] <= gpu_mem_request.write_data[5];
      ram[gpu_mem_request.address[6]] <= gpu_mem_request.write_data[6];
      ram[gpu_mem_request.address[7]] <= gpu_mem_request.write_data[7];
    end
    if (cpu_mem_request.write_enable)
      ram[cpu_mem_request.address] <= cpu_mem_request.write_data;
    if (load_enable) ram[load_address] <= load_data;
  end

  // Registers power up at zero so a program sees empty RAM before it writes.
  initial begin
    for (int i = 0; i < MEMORY_WORDS; i = i + 1) ram[i] = 16'b0;
  end
endmodule
