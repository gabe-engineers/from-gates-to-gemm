`include "isa.svh"
`include "cpu_types.svh"

module decoder (
    input  [15:0] instruction_data,
    output cpu_types_pkg::decoder_out_t out
);

  always @(*) begin
    out.opcode = instruction_data[15:11];
    out.dst_reg = 3'b000;
    out.src_reg_a = 3'b000;
    out.src_reg_b = 3'b000;
    out.immediate = 16'b0;
    out.address = 16'b0;
    out.gpu_command = gpu_types::GPU_COMMAND_NONE;

    case (out.opcode)
      `OP_ADD, `OP_SUB, `OP_SHR, `OP_SHL, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR,
      `OP_VADD, `OP_VSUB, `OP_VMUL, `OP_VDOT: begin
        out.dst_reg   = instruction_data[10:8];
        out.src_reg_a = instruction_data[7:5];
        out.src_reg_b = instruction_data[4:2];
      end

      `OP_LOAD, `OP_VLD: begin
        out.dst_reg   = instruction_data[10:8];
        out.src_reg_b = instruction_data[7:5];
      end

      // Stores are address-first in assembly. The internal B read port remains
      // the ddress port, and A remains the scalar/vector value selector.
      `OP_STORE, `OP_VST: begin
        out.src_reg_b = instruction_data[10:8];
        out.src_reg_a = instruction_data[7:5];
      end

      `OP_CMP: begin
        out.src_reg_a = instruction_data[10:8];
        out.src_reg_b = instruction_data[7:5];
      end

      `OP_MOV: begin
        out.dst_reg   = instruction_data[10:8];
        out.src_reg_a = instruction_data[7:5];
      end

      `OP_LDI: begin
        out.dst_reg   = instruction_data[10:8];
        out.immediate = {8'b0, instruction_data[7:0]};
      end
      `OP_LUI: begin
        out.dst_reg   = instruction_data[10:8];
        out.immediate = {instruction_data[7:0], 8'b0};
      end

      `OP_TID: begin
        out.dst_reg = instruction_data[10:8];
      end

      `OP_JMP, `OP_JE: begin
        out.address = {5'b0, instruction_data[10:0]};
      end

      `OP_GLAUNCH: begin
        out.address = {5'b0, instruction_data[10:0]};
        out.gpu_command = gpu_types::GPU_COMMAND_LAUNCH;
      end

      // GWAIT is handled wholly by the CPU control FSM. It does not send a
      // command to the GPU; the CPU waits on the GPU's registered state.
      `OP_GWAIT: begin end
    endcase
  end
endmodule
