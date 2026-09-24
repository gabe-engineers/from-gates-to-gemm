`include "cpu_types.svh"
`include "register_file.sv"
`include "vector_register_file.sv"
`include "vector_alu.sv"
`include "alu.sv"
`include "control_helpers.svh"

module datapath_16bit (
    input                                       clk,
    input                                       reset,
    input  cpu_types_pkg::scalar_request_t      scalar_request,
    input  cpu_types_pkg::vector_mem_request_t  vector_mem_request,
    input  cpu_types_pkg::vector_alu_request_t  vector_alu_request,
    output cpu_types_pkg::scalar_response_t     scalar_response,
    output cpu_types_pkg::vector_mem_response_t vector_mem_response
);
  wire [ 15:0] alu_out;
  logic [15:0] write_data;
  wire [127:0] vector_alu_read_data_a;
  wire [127:0] vector_alu_read_data_b;
  wire [127:0] vector_alu_out;
  wire [ 15:0] vector_dot_product;

  // The vector dot product overrides the scalar source; otherwise the source
  // selects the immediate, the lane/thread id, or the ALU result.
  always_comb begin
    if (vector_alu_request.dot_writeback_select)
      write_data = vector_dot_product;
    else case (scalar_request.writeback_source)
      control_helpers_pkg::WB_IMMEDIATE: write_data = scalar_request.immediate;
      control_helpers_pkg::WB_THREAD_ID: write_data = {13'b0, scalar_request.thread_id};
      default:                           write_data = alu_out;
    endcase
  end

  register_file registers (
      .clk           (clk),
      .reset         (reset),
      .write_enable  (scalar_request.write_enable),
      .write_addr    (scalar_request.write_addr),
      .write_data    (write_data),
      .read_addr_a   (scalar_request.read_addr_a),
      .read_addr_b   (scalar_request.read_addr_b),
      .read_data_a   (scalar_response.read_data_a),
      .read_data_b   (scalar_response.read_data_b),
      .write_reg_data(scalar_response.write_reg_data)
  );

  alu_16bit alu (
      .operation(scalar_request.alu_op),
      .operand_a(scalar_response.read_data_a),
      .operand_b(scalar_response.read_data_b),
      .result(alu_out),
      .zero_flag(scalar_response.zero_flag),
      .less_than_flag(scalar_response.less_than_flag)
  );

  vector_register_file vector_registers (
      .clk                    (clk),
      .reset                  (reset),
      .write_enable           (vector_mem_request.write_enable),
      .write_addr             (vector_mem_request.write_addr),
      .write_lane             (vector_mem_request.write_lane),
      .write_data             (vector_mem_request.write_data),
      .read_addr              (vector_mem_request.read_addr),
      .read_lane              (vector_mem_request.read_lane),
      .read_data              (vector_mem_response.read_data),
      .vector_alu_write_enable(vector_alu_request.write_enable),
      .vector_alu_write_addr  (vector_alu_request.write_addr),
      .vector_alu_write_data  (vector_alu_out),
      .vector_alu_read_addr_a (vector_alu_request.read_addr_a),
      .vector_alu_read_addr_b (vector_alu_request.read_addr_b),
      .vector_alu_read_data_a (vector_alu_read_data_a),
      .vector_alu_read_data_b (vector_alu_read_data_b)
  );

  vector_alu_16bit vector_alu (
      .operation  (vector_alu_request.operation),
      .a          (vector_alu_read_data_a),
      .b          (vector_alu_read_data_b),
      .out        (vector_alu_out),
      .dot_product(vector_dot_product)
  );
endmodule
