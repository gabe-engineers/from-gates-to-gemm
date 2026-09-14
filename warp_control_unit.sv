
module warp_control_unit (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    input [15:0] datapath_read_data_a,
    input [15:0] datapath_read_data_b
);

  typedef struct packed {
    logic [15:0] datapath_read_data_a;
    logic [15:0] datapath_read_data_b;
  } lane_request_t;



endmodule
