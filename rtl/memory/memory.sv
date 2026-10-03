`include "cpu_types.svh"
`include "gpu_types.svh"

localparam int MEMORY_WORDS = 1024;

module memory #(
    parameter INIT_FILE = "",
    parameter INIT_PREFIX = "",
    parameter GEMM_SCRATCH_MODE = 1'b0,
    parameter [15:0] GEMM_C_BASE = 16'd116
) (
    input                                         clk,
    input                                         reset,
    input  cpu_types_pkg::cpu_mem_request_t       cpu_mem_request,
    input  gpu_types::warp_mem_request_t          gpu_mem_request,
    input                                         gpu_active,
    input                                         inspect_enable,
    input                                         load_enable,
    input                                  [15:0] load_address,
    input                                  [15:0] load_data,
    input                                  [15:0] inspect_address,
    output                                 [15:0] inspect_data,
    output                                 [15:0] cpu_read_data,
    output gpu_types::warp_mem_response_t         gpu_read_response
);
  // The general chip retains its full multi-port RAM model. The GEMM FPGA
  // variant below banks reads and keeps GPU lane partials in eight registers.
  logic [15:0] ram[0:MEMORY_WORDS-1];
  wire [7:0][15:0] gpu_read_words;
  assign gpu_read_response.read_data = gpu_read_words;

  generate
    if (GEMM_SCRATCH_MODE) begin : gemm_fpga
      logic [15:0] bank0[0:127];
      logic [15:0] bank1[0:127];
      logic [15:0] bank2[0:127];
      logic [15:0] bank3[0:127];
      logic [15:0] bank4[0:127];
      logic [15:0] bank5[0:127];
      logic [15:0] bank6[0:127];
      logic [15:0] bank7[0:127];
      logic [15:0] scratch[0:7];
      logic [6:0] bank_read_index[0:7];
      wire [15:0] bank_read_word[0:7];
      wire [15:0] cpu_bank_word[0:7];

      function automatic is_scratch(input [15:0] address);
        is_scratch = address >= 16'd108 && address <= 16'd115;
      endfunction

      function automatic [2:0] scratch_index(input [15:0] address);
        scratch_index = address[2:0] - 3'd4;
      endfunction

      // The CPU must fetch GWAIT after launching the GPU, so it keeps a read
      // path while the GPU reads. At HALT, inspection reuses the GPU path.
      always_comb begin
        for (int bank = 0; bank < 8; bank = bank + 1) begin
          bank_read_index[bank] = inspect_address[9:3];
          if (gpu_active)
            for (int lane = 0; lane < 8; lane = lane + 1)
              if (gpu_mem_request.address[lane][2:0] == bank[2:0])
                bank_read_index[bank] = gpu_mem_request.address[lane][9:3];
        end
      end

      assign bank_read_word[0] = bank0[bank_read_index[0]];
      assign cpu_bank_word[0] = bank0[cpu_mem_request.address[9:3]];
      assign bank_read_word[1] = bank1[bank_read_index[1]];
      assign cpu_bank_word[1] = bank1[cpu_mem_request.address[9:3]];
      assign bank_read_word[2] = bank2[bank_read_index[2]];
      assign cpu_bank_word[2] = bank2[cpu_mem_request.address[9:3]];
      assign bank_read_word[3] = bank3[bank_read_index[3]];
      assign cpu_bank_word[3] = bank3[cpu_mem_request.address[9:3]];
      assign bank_read_word[4] = bank4[bank_read_index[4]];
      assign cpu_bank_word[4] = bank4[cpu_mem_request.address[9:3]];
      assign bank_read_word[5] = bank5[bank_read_index[5]];
      assign cpu_bank_word[5] = bank5[cpu_mem_request.address[9:3]];
      assign bank_read_word[6] = bank6[bank_read_index[6]];
      assign cpu_bank_word[6] = bank6[cpu_mem_request.address[9:3]];
      assign bank_read_word[7] = bank7[bank_read_index[7]];
      assign cpu_bank_word[7] = bank7[cpu_mem_request.address[9:3]];

      assign cpu_read_data = is_scratch(cpu_mem_request.address) ?
          scratch[scratch_index(cpu_mem_request.address)] :
          cpu_bank_word[cpu_mem_request.address[2:0]];
      assign inspect_data = is_scratch(inspect_address) ?
          scratch[scratch_index(inspect_address)] :
          bank_read_word[inspect_address[2:0]];

      for (genvar lane = 0; lane < 8; lane = lane + 1) begin : gpu_reads
        assign gpu_read_words[lane] = is_scratch(gpu_mem_request.address[lane]) ?
            scratch[scratch_index(gpu_mem_request.address[lane])] :
            bank_read_word[gpu_mem_request.address[lane][2:0]];
      end

      // The checked-in GPU GEMM kernel writes only 108..115. CPU writes are
      // routed either to a lane partial or to exactly one backing bank.
      always @(posedge clk) begin
        if (reset) begin
          for (int i = 0; i < 7; i = i + 1) scratch[i] <= 16'b0;
          scratch[7] <= GEMM_C_BASE;
        end else begin
          if (gpu_mem_request.write_enable)
            for (int lane = 0; lane < 8; lane = lane + 1)
              if (is_scratch(gpu_mem_request.address[lane]))
                scratch[scratch_index(gpu_mem_request.address[lane])] <=
                    gpu_mem_request.write_data[lane];
          if (cpu_mem_request.write_enable) begin
            if (is_scratch(cpu_mem_request.address))
              scratch[scratch_index(cpu_mem_request.address)] <= cpu_mem_request.write_data;
            else
              case (cpu_mem_request.address[2:0])
                3'd0: bank0[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
                3'd1: bank1[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
                3'd2: bank2[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
                3'd3: bank3[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
                3'd4: bank4[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
                3'd5: bank5[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
                3'd6: bank6[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
                3'd7: bank7[cpu_mem_request.address[9:3]] <= cpu_mem_request.write_data;
              endcase
          end
        end
      end

      initial begin
        if (INIT_PREFIX != "") begin
          $readmemh({INIT_PREFIX, "_bank0.mem"}, bank0);
          $readmemh({INIT_PREFIX, "_bank1.mem"}, bank1);
          $readmemh({INIT_PREFIX, "_bank2.mem"}, bank2);
          $readmemh({INIT_PREFIX, "_bank3.mem"}, bank3);
          $readmemh({INIT_PREFIX, "_bank4.mem"}, bank4);
          $readmemh({INIT_PREFIX, "_bank5.mem"}, bank5);
          $readmemh({INIT_PREFIX, "_bank6.mem"}, bank6);
          $readmemh({INIT_PREFIX, "_bank7.mem"}, bank7);
        end
        for (int i = 0; i < 7; i = i + 1) scratch[i] = 16'b0;
        scratch[7] = GEMM_C_BASE;
      end
    end else begin : general_ram
      assign cpu_read_data = ram[cpu_mem_request.address];
      assign inspect_data = ram[inspect_address];
      for (genvar lane = 0; lane < 8; lane = lane + 1) begin : gpu_reads
        assign gpu_read_words[lane] = ram[gpu_mem_request.address[lane]];
      end

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

      initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, ram);
        else for (int i = 0; i < MEMORY_WORDS; i = i + 1) ram[i] = 16'b0;
      end
    end
  endgenerate
endmodule
