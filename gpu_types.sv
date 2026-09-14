package gpu_types;

  typedef struct packed {
    logic [15:0] datapath_read_data_a;
    logic [15:0] datapath_read_data_b;
  } lane_request_t;

endpackage
