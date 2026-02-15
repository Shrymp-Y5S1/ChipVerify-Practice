module axi_mst_wr #(
    parameter OST_DEPTH     = 16,
    parameter MAX_BURST_LEN = 8
) (
  input clk,
  input rst_n,
  // VCS coverage off
  input wr_en,
  // VCS coverage on

  // User Request Interface
  input                                          user_req_valid,
  output                                         user_req_ready,
  input  [                    `AXI_ID_WIDTH-1:0] user_req_id,
  input  [                  `AXI_ADDR_WIDTH-1:0] user_req_addr,
  input  [                   `AXI_LEN_WIDTH-1:0] user_req_len,
  input  [                  `AXI_SIZE_WIDTH-1:0] user_req_size,
  input  [                 `AXI_BURST_WIDTH-1:0] user_req_burst,
  input  [    MAX_BURST_LEN*`AXI_DATA_WIDTH-1:0] user_req_wdata,  // whole burst data
  input  [MAX_BURST_LEN*(`AXI_DATA_WIDTH/8)-1:0] user_req_wstrb,  // whole burst strobe

  // AXI Master Write Address Channel
  output [   `AXI_ID_WIDTH-1:0] axi_mst_awid,
  output [ `AXI_ADDR_WIDTH-1:0] axi_mst_awaddr,
  output [  `AXI_LEN_WIDTH-1:0] axi_mst_awlen,
  output [`AXI_SIZE_WIDTH -1:0] axi_mst_awsize,
  output [`AXI_BURST_WIDTH-1:0] axi_mst_awburst,
  // VCS coverage off
  output [ `AXI_USER_WIDTH-1:0] axi_mst_awuser,
  // VCS coverage on
  output                        axi_mst_awvalid,
  input                         axi_mst_awready,

  // AXI Master Write Data Channel
  output [       `AXI_DATA_WIDTH-1:0] axi_mst_wdata,
  output [(`AXI_DATA_WIDTH >> 3)-1:0] axi_mst_wstrb,
  // VCS coverage off
  output [       `AXI_USER_WIDTH-1:0] axi_mst_wuser,
  // VCS coverage on
  output                              axi_mst_wlast,
  output                              axi_mst_wvalid,
  input                               axi_mst_wready,

  // AXI Master Write Response Channel
  input  [  `AXI_ID_WIDTH-1:0] axi_mst_bid,
  input  [`AXI_RESP_WIDTH-1:0] axi_mst_bresp,
  // VCS coverage off
  input  [`AXI_USER_WIDTH-1:0] axi_mst_buser,
  // VCS coverage on
  input                        axi_mst_bvalid,
  output                       axi_mst_bready
);
  localparam DLY = 1;
  localparam BURST_CNT_WIDTH = $clog2(MAX_BURST_LEN + 1);
  localparam OST_CNT_WIDTH = $clog2(OST_DEPTH + 1);
  localparam MAX_REQ_NUM = 16;
  localparam REQ_CNT_WIDTH = $clog2(MAX_REQ_NUM + 1);
  localparam MAX_GET_DATA_DLY = `AXI_DATA_GET_CNT_WIDTH'h1c;

  // ----------------------------------------------------------------
  // internal registers
  // ----------------------------------------------------------------
  // control and state signals
  wire wr_buff_set;  // decision and config
  wire wr_buff_clr;
  wire wr_buff_full;
  reg wr_buff_set_r;  // start subsequent process

  reg wr_valid_buff_r[OST_DEPTH-1:0];
  reg wr_req_buff_r[OST_DEPTH-1:0];
  reg wr_data_ready_r[OST_DEPTH-1:0];
  reg wr_comp_buff_r[OST_DEPTH-1:0];
  reg wr_clear_buff_r[OST_DEPTH-1:0];

  // bit vectors
  reg [OST_DEPTH-1:0] wr_valid_bits;
  wire [OST_DEPTH-1:0] wr_set_bits;
  reg [OST_DEPTH-1:0] wr_req_bits;
  reg [OST_DEPTH-1:0] wr_clear_bits;
  wire [OST_DEPTH-1:0] wr_order_bits;

  // Write pointers
  wire [OST_CNT_WIDTH-1:0] wr_ptr_set;  // decision and config
  wire [OST_CNT_WIDTH-1:0] wr_ptr_clr;
  wire [OST_CNT_WIDTH-1:0] wr_ptr_req;
  wire [OST_CNT_WIDTH-1:0] wr_ptr_data;
  wire [OST_CNT_WIDTH-1:0] wr_ptr_result;
  reg [OST_CNT_WIDTH-1:0] wr_ptr_set_r;  // start subsequent process

  // Write request buffers
  reg [`AXI_ID_WIDTH-1:0] wr_id_buff_r[OST_DEPTH-1:0];
  reg [`AXI_ADDR_WIDTH-1:0] wr_addr_buff_r[OST_DEPTH-1:0];
  reg [`AXI_LEN_WIDTH-1:0] wr_len_buff_r[OST_DEPTH-1:0];
  reg [`AXI_SIZE_WIDTH-1:0] wr_size_buff_r[OST_DEPTH-1:0];
  reg [`AXI_BURST_WIDTH-1:0] wr_burst_buff_r[OST_DEPTH-1:0];

  // Write data and response buffers
  reg [MAX_BURST_LEN-1:0] wr_data_vld_r[OST_DEPTH-1:0];
  reg [`AXI_DATA_WIDTH*MAX_BURST_LEN-1:0] wr_data_buff_r[OST_DEPTH-1:0];
  reg [(`AXI_DATA_WIDTH >> 3)*MAX_BURST_LEN-1:0] wr_strb_buff_r[OST_DEPTH-1:0];
  reg [BURST_CNT_WIDTH-1:0] wr_data_cnt_r[OST_DEPTH-1:0];
  reg [`AXI_RESP_WIDTH-1:0] wr_resp_buff_r[OST_DEPTH-1:0];

  // Write handshake signals
  wire wr_req_en;
  wire wr_data_en;
  wire wr_data_last;
  wire wr_data_src_valid;
  wire [`AXI_DATA_WIDTH-1:0] wr_data_src_data;
  wire [(`AXI_DATA_WIDTH >> 3)-1:0] wr_data_src_strb;
  wire wr_data_src_last;

  // Write response
  wire wr_result_en;
  wire [`AXI_ID_WIDTH-1:0] wr_result_id;

  // AW output holding registers
  reg aw_out_valid_r;
  reg aw_out_arm_r;
  reg [OST_CNT_WIDTH-1:0] aw_out_ptr_r;

  // W output holding registers
  reg w_out_valid_r;
  reg w_out_arm_r;
  reg [`AXI_DATA_WIDTH-1:0] w_out_data_r;
  reg [(`AXI_DATA_WIDTH >> 3)-1:0] w_out_strb_r;
  reg w_out_last_r;

  wire [OST_CNT_WIDTH-1:0] final_ptr_req;

  // ----------------------------------------------------------------
  // Pointer Logic
  // ----------------------------------------------------------------
  axi_arbit #(
    .ARB_WIDTH(OST_DEPTH)
  ) u_wr_set_arbit (
    .clk      (clk),
    .rst_n    (rst_n),
    .queue_i  (wr_set_bits),
    .sche_en  (wr_buff_set),
    .pointer_o(wr_ptr_set)
  );
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_buff_set_r <= #DLY 1'b0;
      wr_ptr_set_r  <= #DLY{OST_CNT_WIDTH{1'b0}};
    end
    else begin
      wr_buff_set_r <= #DLY wr_buff_set;
      wr_ptr_set_r  <= #DLY wr_ptr_set;
    end
  end

  axi_arbit #(
    .ARB_WIDTH(OST_DEPTH)
  ) u_wr_clr_arbit (
    .clk      (clk),
    .rst_n    (rst_n),
    .queue_i  (wr_clear_bits),
    .sche_en  (wr_buff_clr),
    .pointer_o(wr_ptr_clr)
  );

  axi_arbit #(
    .ARB_WIDTH(OST_DEPTH)
  ) u_wr_req_arbit (
    .clk      (clk),
    .rst_n    (rst_n),
    .queue_i  (wr_req_bits),
    .sche_en  (wr_req_en),
    .pointer_o(wr_ptr_req)
  );

  // ----------------------------------------------------------------
  // Main Control
  // ----------------------------------------------------------------
  // array -> register conversion
  always @(*) begin : MST_WR_VALID_VEC
    integer i;
    wr_valid_bits = {OST_DEPTH{1'b0}};
    for (i = 0; i < OST_DEPTH; i = i + 1) begin
      wr_valid_bits[i] = wr_valid_buff_r[i];
    end
  end

  always @(*) begin : MST_WR_REQ_VEC
    integer i;
    wr_req_bits = {OST_DEPTH{1'b0}};
    for (i = 0; i < OST_DEPTH; i = i + 1) begin
      wr_req_bits[i] = wr_req_buff_r[i];
    end
  end

  always @(*) begin : MST_WR_CLEAR_VEC
    integer i;
    wr_clear_bits = {OST_DEPTH{1'b0}};
    for (i = 0; i < OST_DEPTH; i = i + 1) begin
      wr_clear_bits[i] = wr_clear_buff_r[i];
    end
  end

  assign wr_buff_full = &wr_valid_bits;
  assign wr_buff_set = ~wr_buff_full & user_req_valid & wr_en;
  assign wr_set_bits = ~wr_valid_bits;

  assign wr_buff_clr =
      wr_valid_buff_r[wr_ptr_clr] & ~wr_req_buff_r[wr_ptr_clr] & ~wr_comp_buff_r[wr_ptr_clr];

  assign wr_req_en = aw_out_valid_r & axi_mst_awready;
  assign wr_data_en = axi_mst_wvalid & axi_mst_wready;
  assign wr_data_last = axi_mst_wlast;
  assign wr_result_en = axi_mst_bvalid & axi_mst_bready;

  genvar i;
  generate
    for (i = 0; i < OST_DEPTH; i = i + 1) begin : MST_WR_BUFFERS
      // Valid Buffer Register
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_valid_buff_r[i] <= #DLY 1'b0;
        end
        else if (wr_buff_set && (i == wr_ptr_set)) begin
          wr_valid_buff_r[i] <= #DLY 1'b1;
        end
        else if (wr_buff_clr && (i == wr_ptr_clr)) begin
          wr_valid_buff_r[i] <= #DLY 1'b0;
        end
      end

      // Request Buffer Register
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_req_buff_r[i] <= #DLY 1'b0;
        end
        else if (wr_buff_set && (i == wr_ptr_set)) begin
          wr_req_buff_r[i] <= #DLY 1'b1;
        end
        else if (wr_req_en && (i == aw_out_ptr_r)) begin
          wr_req_buff_r[i] <= #DLY 1'b0;
        end
      end

      // Data ready Register
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_data_ready_r[i] <= #DLY 1'b0;
        end
        else begin
          if (wr_buff_set && (i == wr_ptr_set)) begin
            wr_data_ready_r[i] <= #DLY 1'b1;
          end
          else if (wr_data_en && ~wr_data_last && (wr_ptr_data == i) &&
                   wr_data_vld_r[i][wr_data_cnt_r[i]+1]) begin
            // Data ready for next beat when current beat is valid and not last
            wr_data_ready_r[i] <= #DLY 1'b1;
          end
          else if (wr_data_en && (wr_ptr_data == i)) begin
            wr_data_ready_r[i] <= #DLY 1'b0;
          end
        end
      end

      // Completion Buffer Register
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_comp_buff_r[i] <= #DLY 1'b0;
        end
        else if (wr_buff_set && (i == wr_ptr_set)) begin
          wr_comp_buff_r[i] <= #DLY 1'b1;
        end
        else if (wr_result_en & (wr_ptr_result == i)) begin
          wr_comp_buff_r[i] <= #DLY 1'b0;
        end
      end

      // Clear Buffer Register
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_clear_buff_r[i] <= #DLY 1'b0;
        end
        else begin
          wr_clear_buff_r[i] <= #DLY wr_valid_buff_r[i] & ~wr_req_buff_r[i] & ~wr_comp_buff_r[i];
        end
      end

      // ----------------------------------------------------------------
      // AXI AW Payload Buffer
      // ----------------------------------------------------------------
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_id_buff_r[i]    <= #DLY `AXI_ID_WIDTH'h0;
          wr_addr_buff_r[i]  <= #DLY `AXI_ADDR_WIDTH'h0;
          wr_len_buff_r[i]   <= #DLY `AXI_LEN_WIDTH'h0;
          wr_size_buff_r[i]  <= #DLY `AXI_SIZE_1_BYTE;
          wr_burst_buff_r[i] <= #DLY `AXI_BURST_INCR;
        end
        else if (wr_buff_set && (wr_ptr_set == i)) begin
          wr_id_buff_r[i]    <= #DLY user_req_id;
          wr_addr_buff_r[i]  <= #DLY user_req_addr;
          wr_len_buff_r[i]   <= #DLY user_req_len;
          wr_size_buff_r[i]  <= #DLY user_req_size;
          wr_burst_buff_r[i] <= #DLY user_req_burst;
        end
      end

      // ----------------------------------------------------------------
      // AXI W Payload Buffer
      // ----------------------------------------------------------------
      // Write Data Counter
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_data_cnt_r[i] <= #DLY{BURST_CNT_WIDTH{1'b0}};
        end
        else if (wr_buff_set && (wr_ptr_set == i)) begin
          wr_data_cnt_r[i] <= #DLY{BURST_CNT_WIDTH{1'b0}};
        end
        else if (wr_data_en && (wr_ptr_data == i)) begin
          wr_data_cnt_r[i] <= #DLY wr_data_cnt_r[i] + 1'b1;
        end
      end

      // Write Data Buffer
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_data_buff_r[i] <= #DLY `AXI_DATA_WIDTH'h0;
          wr_data_vld_r[i]  <= #DLY{MAX_BURST_LEN{1'b0}};
          wr_strb_buff_r[i] <= #DLY{(MAX_BURST_LEN * (`AXI_DATA_WIDTH >> 3)) {1'b0}};
        end
        else if (wr_buff_set && (i == wr_ptr_set)) begin
          wr_data_buff_r[i] <= #DLY user_req_wdata;
          wr_strb_buff_r[i] <= #DLY user_req_wstrb;
          wr_data_vld_r[i]  <= #DLY{MAX_BURST_LEN{1'b1}};
        end
      end

      // ----------------------------------------------------------------
      // AXI B RESP Buffer
      // ----------------------------------------------------------------
      // Write Response Buffer
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          wr_resp_buff_r[i] <= #DLY{`AXI_RESP_WIDTH{1'b0}};
        end
        else if (wr_result_en && (wr_ptr_result == i)) begin
          wr_resp_buff_r[i] <= #DLY(axi_mst_bresp > wr_resp_buff_r[i]) ? axi_mst_bresp :
              wr_resp_buff_r[i];
        end
      end
    end
  endgenerate

  // ----------------------------------------------------------------
  // Write Order Control
  // ----------------------------------------------------------------
  // AW channel doesn't carry ID, have to maintain order separately to match with W channel
  axi_order #(
    .OST_DEPTH(OST_DEPTH),
    .ID_WIDTH (`AXI_ID_WIDTH)
  ) u_axi_wr_order (
    .clk       (clk),
    .rst_n     (rst_n),
    .push      (wr_req_en),
    .push_id   (`AXI_ID_WIDTH'h0),
    .push_ptr  (aw_out_ptr_r),
    .pop       (axi_mst_wvalid & axi_mst_wready),
    .pop_id    (`AXI_ID_WIDTH'h0),
    .pop_last  (axi_mst_wlast),
    .order_ptr (wr_ptr_data),
    .order_bits(wr_order_bits)
  );

  // ----------------------------------------------------------------
  // RESP ID ORDER CONTROL
  // ----------------------------------------------------------------
  axi_order #(
    .OST_DEPTH(OST_DEPTH),
    .ID_WIDTH (`AXI_ID_WIDTH)
  ) u_axi_id_order (
    .clk       (clk),
    .rst_n     (rst_n),
    .push      (wr_req_en),
    .push_id   (axi_mst_awid),
    .push_ptr  (aw_out_ptr_r),
    .pop       (axi_mst_bvalid & axi_mst_bready),
    .pop_id    (axi_mst_bid),
    .pop_last  (1'b1),                             // bresp only once
    .order_ptr (wr_ptr_result),
    .order_bits()
  );

  // ----------------------------------------------------------------
  // AW Output Holding
  // ----------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_out_valid_r <= #DLY 1'b0;
      aw_out_arm_r   <= #DLY 1'b0;
      aw_out_ptr_r   <= #DLY{OST_CNT_WIDTH{1'b0}};
    end
    else begin
      if (aw_out_valid_r) begin
        if (axi_mst_awready) begin
          aw_out_valid_r <= #DLY 1'b0;
        end
      end
      else if (aw_out_arm_r) begin
        aw_out_valid_r <= #DLY 1'b1;
        aw_out_arm_r   <= #DLY 1'b0;
      end
      else if (|wr_req_bits) begin
        aw_out_ptr_r <= #DLY wr_ptr_req;
        aw_out_arm_r <= #DLY 1'b1;
      end
    end
  end

  assign final_ptr_req = aw_out_ptr_r;

  // ----------------------------------------------------------------
  // W Source + Output Holding
  // ----------------------------------------------------------------
  assign wr_data_src_valid = wr_valid_buff_r[wr_ptr_data] & wr_data_ready_r[wr_ptr_data] &
      (|wr_order_bits);
  assign wr_data_src_data =
      wr_data_buff_r[wr_ptr_data][(wr_data_cnt_r[wr_ptr_data]*`AXI_DATA_WIDTH)+:`AXI_DATA_WIDTH];
  assign wr_data_src_strb = wr_strb_buff_r[
      wr_ptr_data][(wr_data_cnt_r[wr_ptr_data]*(`AXI_DATA_WIDTH>>3))+:(`AXI_DATA_WIDTH>>3)];
  assign wr_data_src_last = (wr_data_cnt_r[wr_ptr_data] == wr_len_buff_r[wr_ptr_data]);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_out_valid_r <= #DLY 1'b0;
      w_out_arm_r   <= #DLY 1'b0;
      w_out_data_r  <= #DLY{`AXI_DATA_WIDTH{1'b0}};
      w_out_strb_r  <= #DLY{(`AXI_DATA_WIDTH >> 3) {1'b0}};
      w_out_last_r  <= #DLY 1'b0;
    end
    else begin
      if (w_out_valid_r) begin
        if (axi_mst_wready) begin
          w_out_valid_r <= #DLY 1'b0;
        end
      end
      else if (w_out_arm_r) begin
        w_out_valid_r <= #DLY 1'b1;
        w_out_arm_r   <= #DLY 1'b0;
      end
      else if (wr_data_src_valid) begin
        w_out_data_r <= #DLY wr_data_src_data;
        w_out_strb_r <= #DLY wr_data_src_strb;
        w_out_last_r <= #DLY wr_data_src_last;
        w_out_arm_r  <= #DLY 1'b1;
      end
    end
  end


  // ----------------------------------------------------------------
  // Output signal assignments
  // ----------------------------------------------------------------
  // User request ready when buffer not full
  assign user_req_ready  = ~wr_buff_full;

  // AXI Master Write Address Channel
  assign axi_mst_awid    = wr_id_buff_r[final_ptr_req];
  assign axi_mst_awaddr  = wr_addr_buff_r[final_ptr_req];
  assign axi_mst_awlen   = wr_len_buff_r[final_ptr_req];
  assign axi_mst_awsize  = wr_size_buff_r[final_ptr_req];
  assign axi_mst_awburst = wr_burst_buff_r[final_ptr_req];
  assign axi_mst_awvalid = aw_out_valid_r;

  // AXI Master Write Data Channel
  assign axi_mst_wdata   = w_out_data_r;
  assign axi_mst_wstrb   = w_out_strb_r;
  assign axi_mst_wlast   = w_out_last_r;
  assign axi_mst_wvalid  = w_out_valid_r;

  // AXI Master Write Response Channel
  assign axi_mst_bready  = 1'b1;

endmodule
