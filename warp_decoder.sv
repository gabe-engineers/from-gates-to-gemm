`include "gpu_types.svh"
`include "isa.svh"

// Warps execute a scalar/SIMT instruction stream: one supported instruction
// is broadcast to every lane. CPU SIMD and CPU/GPU coordination instructions
// are intentionally not part of this ISA.
module warp_decoder (
    input [15:0] instruction_data,
    output gpu_types::warp_decoder_out_t out
);

  always @(*) begin
    out = '0;
    out.opcode = instruction_data[15:11];

    case (out.opcode)
      `OP_ADD, `OP_SUB, `OP_SHR, `OP_SHL, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR: begin
        out.valid     = 1'b1;
        out.dst_reg   = instruction_data[10:8];
        out.src_reg_a = instruction_data[7:5];
        out.src_reg_b = instruction_data[4:2];
      end

      `OP_MOV: begin
        out.valid     = 1'b1;
        out.dst_reg   = instruction_data[10:8];
        out.src_reg_a = instruction_data[7:5];
      end

      `OP_LDI: begin
        out.valid     = 1'b1;
        out.dst_reg   = instruction_data[10:8];
        out.immediate = {8'b0, instruction_data[7:0]};
      end

      `OP_LUI: begin
        out.valid     = 1'b1;
        out.dst_reg   = instruction_data[10:8];
        out.immediate = {instruction_data[7:0], 8'b0};
      end

      `OP_TID: begin
        out.valid   = 1'b1;
        out.dst_reg = instruction_data[10:8];
      end

      `OP_HALT: begin
        out.valid = 1'b1;
      end
    endcase
  end

endmodule
