`include "register.sv"
`include "gpu_types.sv"

module memory (
    input                                     clk,
    input                              [15:0] cpu_address,
    input                                     cpu_write_enable,
    input                              [15:0] cpu_write_data,
    input                                     gpu_write_enable,
    input  gpu_types::warp_mem_request        gpu_mem_request,
    output                             [15:0] cpu_read_data,
    output                    [7:0][15:0] gpu_read_data
);
  wire [15:0] register_out[0:511];

  // Access outside the implemented 512-word RAM is architecturally undefined.
  assign cpu_read_data = register_out[cpu_address];

  generate
    for (genvar i = 0; i < 512; i++) begin : memory_words
      wire cpu_writes_this_word;
      wire [7:0] gpu_writes_this_word;
      wire [15:0] gpu_write_data_this_word;

      assign cpu_writes_this_word = cpu_write_enable && (cpu_address == i);

      for (genvar gpu_i = 0; gpu_i < 8; gpu_i++) begin : gpu_writes
        assign gpu_writes_this_word[gpu_i] =
            gpu_write_enable && (gpu_mem_request.mem_address[gpu_i] == i);
      end

      // If GPU lanes target the same word, the highest-numbered lane wins.
      // CPU priority below remains higher than every GPU lane.
      assign gpu_write_data_this_word =
          gpu_writes_this_word[7] ? gpu_mem_request.mem_write_data[7] :
          gpu_writes_this_word[6] ? gpu_mem_request.mem_write_data[6] :
          gpu_writes_this_word[5] ? gpu_mem_request.mem_write_data[5] :
          gpu_writes_this_word[4] ? gpu_mem_request.mem_write_data[4] :
          gpu_writes_this_word[3] ? gpu_mem_request.mem_write_data[3] :
          gpu_writes_this_word[2] ? gpu_mem_request.mem_write_data[2] :
          gpu_writes_this_word[1] ? gpu_mem_request.mem_write_data[1] :
                                   gpu_mem_request.mem_write_data[0];

      register register (
          .clk(clk),
          .reset(1'b0),
          .write_enable(cpu_writes_this_word || |gpu_writes_this_word),
          // CPU wins if both ports write the same word on the same clock edge.
          .data_in(cpu_writes_this_word ? cpu_write_data : gpu_write_data_this_word),
          .data_out(register_out[i])
      );
    end

    for (genvar gpu_i = 0; gpu_i < 8; gpu_i++) begin : gpu_reads
      assign gpu_read_data[gpu_i] = register_out[gpu_mem_request.mem_address[gpu_i]];
    end
  endgenerate


endmodule
