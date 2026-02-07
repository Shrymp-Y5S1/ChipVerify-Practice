module axi_slv_wr #(
        parameter OST_DEPTH = 16
    )(
        input clk,
        input rst_n,

        // AXI Slave Write Address Channel
        input [`AXI_ID_WIDTH-1:0] axi_slv_awid,
        input [`AXI_ADDR_WIDTH-1:0] axi_slv_awaddr,
        input [`AXI_LEN_WIDTH-1:0] axi_slv_awlen,
        input [`AXI_SIZE_WIDTH -1:0] axi_slv_awsize,
        input [`AXI_BURST_WIDTH-1:0] axi_slv_awburst,
        input [`AXI_USER_WIDTH-1:0] axi_slv_awuser,
        input axi_slv_awvalid,
        output axi_slv_awready,

        // AXI Slave Write Data Channel
        input [`AXI_DATA_WIDTH-1:0] axi_slv_wdata,
        input [(`AXI_DATA_WIDTH >> 3)-1:0] axi_slv_wstrb,
        input [`AXI_USER_WIDTH-1:0] axi_slv_wuser,
        input axi_slv_wlast,
        input axi_slv_wvalid,
        output axi_slv_wready,

        // AXI Slave Write Response Channel
        output [`AXI_ID_WIDTH-1:0] axi_slv_bid,
        output [`AXI_RESP_WIDTH-1:0] axi_slv_bresp,
        output [`AXI_USER_WIDTH-1:0] axi_slv_buser,
        output axi_slv_bvalid,
        input axi_slv_bready
    );

    localparam MAX_BURST_LEN = 8;
    localparam BURST_CNT_WIDTH = $clog2(MAX_BURST_LEN+1);
    localparam REG_ADDR = 16'h0;
    localparam OST_CNT_WIDTH = $clog2(OST_DEPTH + 1);
    localparam MAX_GET_RESP_DLY = `AXI_RESP_GET_CNT_WIDTH'h1f;  // max delay cycles for getting response

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------
    // control and state signals
    wire wr_buff_set;
    wire wr_buff_clr;
    wire wr_buff_full;

    reg wr_valid_buff_r [OST_DEPTH-1:0];
    reg wr_result_buff_r [OST_DEPTH-1:0];
    reg wr_comp_buff_r [OST_DEPTH-1:0];
    reg wr_clear_buff_r [OST_DEPTH-1:0];

    // bit vectors
    reg [OST_DEPTH-1:0] wr_valid_bits;
    wire [OST_DEPTH-1:0] wr_set_bits;
    reg [OST_DEPTH-1:0] wr_clear_bits;
    reg [OST_DEPTH-1:0] wr_result_bits;
    wire [OST_DEPTH-1:0] wr_order_bits;

    // Write pointers
    wire [OST_CNT_WIDTH-1:0] wr_ptr_set;
    wire [OST_CNT_WIDTH-1:0] wr_ptr_clr;
    wire [OST_CNT_WIDTH-1:0] wr_ptr_data;
    wire [OST_CNT_WIDTH-1:0] wr_ptr_result;

    // Write request buffers
    reg [`AXI_LEN_WIDTH-1:0] wr_curr_index_r [OST_DEPTH-1:0];
    reg [`AXI_ID_WIDTH-1:0] wr_id_buff_r [OST_DEPTH-1:0];
    reg [`AXI_ADDR_WIDTH-1:0] wr_addr_buff_r [OST_DEPTH-1:0];
    reg [`AXI_LEN_WIDTH-1:0] wr_len_buff_r [OST_DEPTH-1:0];
    reg [`AXI_SIZE_WIDTH-1:0] wr_size_buff_r [OST_DEPTH-1:0];
    reg [`AXI_BURST_WIDTH-1:0] wr_burst_buff_r [OST_DEPTH-1:0];
    reg [`AXI_USER_WIDTH-1:0] wr_user_buff_r [OST_DEPTH-1:0];

    // Hold write data beats and track per-burst data valid and responses
    reg [MAX_BURST_LEN-1:0] wr_data_vld_r [OST_DEPTH-1:0];
    reg [MAX_BURST_LEN*`AXI_DATA_WIDTH-1:0] wr_data_buff_r [OST_DEPTH-1:0];
    reg [BURST_CNT_WIDTH-1:0] wr_data_cnt_r [OST_DEPTH-1:0];
    reg [`AXI_RESP_WIDTH-1:0] wr_resp_buff_r [OST_DEPTH-1:0];

    // Write response tracking
    wire wr_dec_miss;
    wire wr_result_en;
    wire [`AXI_ID_WIDTH-1:0] wr_result_id;
    wire wr_data_en;
    wire wr_data_last;

    // // burst address signals
    wire [`AXI_ADDR_WIDTH-1:0] wr_start_addr [OST_DEPTH-1:0];
    wire [`AXI_LEN_WIDTH-1:0] wr_burst_len [OST_DEPTH-1:0];
    wire [(1 << `AXI_SIZE_WIDTH)-1:0] wr_number_bytes [OST_DEPTH-1:0];
    wire [`AXI_ADDR_WIDTH-1:0] wr_wrap_boundary [OST_DEPTH-1:0];
    wire [`AXI_ADDR_WIDTH-1:0] wr_aligned_addr [OST_DEPTH-1:0];
    wire wr_wrap_done  [OST_DEPTH-1:0];
    reg wr_wrap_done_r [OST_DEPTH-1:0];
    reg [`AXI_ADDR_WIDTH-1:0] wr_curr_addr_r [OST_DEPTH-1:0];

    // Simulation response/data signals
    reg [`AXI_DATA_GET_CNT_WIDTH-1:0] wr_resp_get_cnt [OST_DEPTH-1:0];
    wire wr_resp_get_cnt_en [OST_DEPTH-1:0];
    wire wr_resp_get [OST_DEPTH-1:0];
    wire wr_resp_err [OST_DEPTH-1:0];

    // ----------------------------------------------------------------
    // Pointer Logic
    // ----------------------------------------------------------------
    axi_arbit #(
                  .ARB_WIDTH 	(OST_DEPTH  ))
              u_wr_set_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(wr_set_bits    ),
                  .sche_en   	(wr_buff_set    ),
                  .pointer_o 	(wr_ptr_set  )
              );

    axi_arbit #(
                  .ARB_WIDTH 	(OST_DEPTH  ))
              u_wr_clr_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(wr_clear_bits    ),
                  .sche_en   	(wr_buff_clr    ),
                  .pointer_o 	(wr_ptr_clr  )
              );

    axi_arbit #(
                  .ARB_WIDTH 	(OST_DEPTH  ))
              u_wr_result_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(wr_result_bits & wr_order_bits),
                  .sche_en   	(wr_result_en    ),
                  .pointer_o 	(wr_ptr_result  )
              );

    // ----------------------------------------------------------------
    // Main Control
    // ----------------------------------------------------------------
    // array -> register conversion
    always @(*) begin: SLV_WR_VALID_VEC
        integer i;
        wr_valid_bits = {OST_DEPTH{1'b0}};
        for (i=0;i < OST_DEPTH; i=i+1) begin
            wr_valid_bits[i] = wr_valid_buff_r[i];
        end
    end

    always @(*) begin: SLV_WR_RESULT_VEC
        integer i;
        wr_result_bits = {OST_DEPTH{1'b0}};
        for (i=0;i < OST_DEPTH; i=i+1) begin
            wr_result_bits[i] = wr_result_buff_r[i];
        end
    end

    always @(*) begin: SLV_WR_CLR_VEC
        integer i;
        wr_clear_bits = {OST_DEPTH{1'b0}};
        for(i=0; i<OST_DEPTH; i=i+1) begin
            wr_clear_bits[i] = wr_clear_buff_r[i];
        end
    end

    assign wr_buff_full = &wr_valid_bits;
    assign wr_set_bits = ~wr_valid_bits;

    assign wr_buff_set = axi_slv_awvalid & axi_slv_awready;
    assign wr_buff_clr = wr_valid_buff_r[wr_ptr_clr] & ~wr_result_buff_r[wr_ptr_clr] & ~wr_comp_buff_r[wr_ptr_clr];

    assign wr_dec_miss = 1'b0;
    assign wr_data_en = axi_slv_wvalid & axi_slv_wready;
    assign wr_data_last = axi_slv_wlast;
    assign wr_result_id = axi_slv_bid;
    assign wr_result_en = axi_slv_bvalid & axi_slv_bready;

    genvar i;
    generate
        for (i=0; i<OST_DEPTH; i=i+1) begin: SLV_WR_BUFFERS
            // Valid Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_valid_buff_r[i] <= #`DLY 1'b0;
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_valid_buff_r[i] <= #`DLY 1'b1;
                end
                else if(wr_buff_clr && (i == wr_ptr_clr)) begin
                    wr_valid_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // Result sent Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_result_buff_r[i] <= #`DLY 1'b0;
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_result_buff_r[i] <= #`DLY wr_dec_miss ? 1'b1 : 1'b0;  // If address decode miss, set result buffer immediately to avoid waiting for write data handshake
                end
                else if(wr_resp_get[i]) begin
                    wr_result_buff_r[i] <= #`DLY 1'b1;
                end
                else if(wr_result_en && (i == wr_ptr_result)) begin
                    wr_result_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // Completion Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_comp_buff_r[i] <= #`DLY 1'b0;
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_comp_buff_r[i] <= #`DLY 1'b1;
                end
                else if(wr_result_en && (i == wr_ptr_result)) begin
                    wr_comp_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // Clear Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_clear_buff_r[i] <= #`DLY 1'b0;
                end
                else begin
                    wr_clear_buff_r[i] <= #`DLY wr_valid_buff_r[i] & ~wr_result_buff_r[i] & ~wr_comp_buff_r[i];
                end
            end

            // ----------------------------------------------------------------
            // AXI AW Payload Buffer
            // ----------------------------------------------------------------
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_id_buff_r[i] <= #`DLY `AXI_ID_WIDTH'h0;
                    wr_addr_buff_r[i] <= #`DLY `AXI_ADDR_WIDTH'h0;
                    wr_len_buff_r[i] <= #`DLY `AXI_LEN_WIDTH'h0;
                    wr_size_buff_r[i] <= #`DLY `AXI_SIZE_1_BYTE;
                    wr_burst_buff_r[i] <= #`DLY `AXI_BURST_INCR;
                    wr_user_buff_r[i] <=#`DLY `AXI_USER_WIDTH'h0;
                end
                else if(wr_buff_set && (wr_ptr_set == i)) begin
                    wr_id_buff_r[i] <= #`DLY axi_slv_awid;
                    wr_addr_buff_r[i] <= #`DLY axi_slv_awaddr;
                    wr_len_buff_r[i] <= #`DLY axi_slv_awlen;
                    wr_size_buff_r[i] <= #`DLY axi_slv_awsize;
                    wr_burst_buff_r[i] <= #`DLY axi_slv_awburst;
                    wr_user_buff_r[i] <=#`DLY axi_slv_awuser;
                end
            end

            // ----------------------------------------------------------------
            // Address Calculation
            // ----------------------------------------------------------------
            assign wr_start_addr[i] = (wr_buff_set && (i == wr_ptr_set)) ? axi_slv_awaddr : wr_addr_buff_r[i];
            assign wr_number_bytes[i] = (wr_buff_set && (i == wr_ptr_set)) ? 1 << axi_slv_awsize : 1 << wr_size_buff_r[i];
            assign wr_burst_len[i] = (wr_buff_set && (i == wr_ptr_set)) ? axi_slv_awlen + 1 : wr_len_buff_r[i] + 1;
            assign wr_aligned_addr[i] = wr_start_addr[i] / wr_number_bytes[i] * wr_number_bytes[i];
            assign wr_wrap_boundary[i] = wr_start_addr[i] / (wr_burst_len[i] * wr_number_bytes[i]) * (wr_burst_len[i] * wr_number_bytes[i]);
            assign wr_wrap_done[i] = (wr_curr_addr_r[i] + wr_number_bytes[i]) == (wr_wrap_boundary[i] + (wr_burst_len[i] * wr_number_bytes[i]));

            // Write index calculation
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_curr_index_r[i] <= #`DLY `AXI_LEN_WIDTH'h0;
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_curr_index_r[i] <= #`DLY wr_dec_miss ? wr_burst_len[i] : `AXI_LEN_WIDTH'h1;
                end
                else if(wr_result_en && (i == wr_ptr_result)) begin
                    wr_curr_index_r[i] <= #`DLY `AXI_LEN_WIDTH'h0;
                end
                else if(wr_data_en) begin
                    wr_curr_index_r[i] <= #`DLY wr_curr_index_r[i] + 1'b1;
                end
            end

            // Write address wrap control
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_wrap_done_r[i] <= #`DLY 1'b0;
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_wrap_done_r[i] <= #`DLY 1'b0;
                end
                else if(wr_data_en) begin
                    wr_wrap_done_r[i] <= #`DLY wr_wrap_done[i] | wr_wrap_done_r[i]; // if wrapped, keep done until next burst
                end
            end

            // Current address calculation
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_curr_addr_r[i] <= #`DLY `AXI_ADDR_WIDTH'h0;
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_curr_addr_r[i] <= #`DLY wr_start_addr[i];
                end
                else if(wr_data_en) begin
                    case (wr_burst_buff_r[i])
                        `AXI_BURST_FIXED:
                            wr_curr_addr_r[i] <= #`DLY wr_start_addr[i];
                        `AXI_BURST_INCR:
                            wr_curr_addr_r[i] <= #`DLY wr_aligned_addr[i] + (wr_curr_index_r[i] * wr_number_bytes[i]);
                        `AXI_BURST_WRAP: begin
                            if(wr_wrap_done[i])
                                wr_curr_addr_r[i] <= #`DLY wr_wrap_boundary[i];
                            else if(wr_wrap_done_r[i])
                                wr_curr_addr_r[i] <= #`DLY wr_start_addr[i] + (wr_curr_index_r[i] * wr_number_bytes[i]) - (wr_burst_len[i] * wr_number_bytes[i]);
                            else
                                wr_curr_addr_r[i] <= #`DLY wr_aligned_addr[i] + (wr_curr_index_r[i] * wr_number_bytes[i]);
                        end
                        default:
                            wr_curr_addr_r[i] <= #`DLY `AXI_ADDR_WIDTH'h0;
                    endcase
                end
            end

            // ----------------------------------------------------------------
            // AXI W Payload Buffer and Response Tracking
            // ----------------------------------------------------------------
            // Write Response Buffer
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_resp_buff_r[i] <= #`DLY {`AXI_RESP_WIDTH{1'b0}};
                end
                else if(wr_buff_set && (wr_ptr_set == i)) begin
                    wr_resp_buff_r[i] <= #`DLY wr_dec_miss ? `AXI_RESP_DECERR : `AXI_RESP_OKAY;
                end
                else if(wr_resp_get[i]) begin
                    wr_resp_buff_r[i] <= #`DLY wr_resp_err[i] ? `AXI_RESP_SLVERR : `AXI_RESP_OKAY;
                end
            end
            // Write Response Error Flag
            assign wr_resp_err[i] = (wr_id_buff_r[i] == `AXI_ID_WIDTH'hF); // if ID is F, treat it as error for simulation purposes

            // Write Data Counter
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(wr_buff_set && (wr_ptr_set == i)) begin
                    wr_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(wr_data_en && (wr_ptr_data == i)) begin
                    wr_data_cnt_r[i] <= #`DLY wr_data_cnt_r[i] + 1'b1;
                end
            end
            // Write Data Buffer
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_data_buff_r[i] <= #`DLY {`AXI_DATA_WIDTH*MAX_BURST_LEN{1'b0}};
                    wr_data_vld_r[i] <= #`DLY {MAX_BURST_LEN{1'b0}};
                end
                else if(wr_buff_set && (wr_ptr_set == i)) begin
                    wr_data_buff_r[i] <= #`DLY {`AXI_DATA_WIDTH*MAX_BURST_LEN{1'b0}};
                    wr_data_vld_r[i] <= #`DLY {MAX_BURST_LEN{1'b0}};
                end
                // else if(wr_data_en && (wr_ptr_data == i)) begin
                else if(wr_data_en) begin
                    wr_data_buff_r[i][((wr_curr_index_r[i]-1)*`AXI_DATA_WIDTH) +: `AXI_DATA_WIDTH] <= # `DLY axi_slv_wdata;
                    wr_data_vld_r[i][wr_curr_index_r[i]-1] <= # `DLY 1'b1;
                end
            end

            // ----------------------------------------------------------------
            // Simulate the data reading process
            // ----------------------------------------------------------------
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_resp_get_cnt[i] <= #`DLY `AXI_RESP_GET_CNT_WIDTH'h0;
                end
                else if(wr_data_en && wr_data_last && (i == wr_ptr_data)) begin
                    wr_resp_get_cnt[i] <= #`DLY `AXI_RESP_GET_CNT_WIDTH'h1;
                end     // write last data beat received, start counting to get response
                else if(wr_resp_get_cnt[i] == MAX_GET_RESP_DLY) begin
                    wr_resp_get_cnt[i] <= #`DLY `AXI_RESP_GET_CNT_WIDTH'h0;
                end
                else if(wr_resp_get_cnt[i] > `AXI_RESP_GET_CNT_WIDTH'h0) begin
                    wr_resp_get_cnt[i] <= #`DLY wr_resp_get_cnt[i] + 1'b1;
                end
            end
            assign wr_resp_get[i] = wr_valid_buff_r[i] & (wr_resp_get_cnt[i] == MAX_GET_RESP_DLY - (2 * wr_id_buff_r[i]));    // Response get condition, simulate out-of-order response based on ID

        end
    endgenerate

    // ----------------------------------------------------------------
    // W DATA Order Control
    // ----------------------------------------------------------------
    // AW channel doesn't carry ID, use constant
    axi_order #(
                  .OST_DEPTH 	(OST_DEPTH  ),
                  .ID_WIDTH  	(`AXI_ID_WIDTH))
              u_axi_wr_order(
                  .clk        	(clk         ),
                  .rst_n      	(rst_n       ),
                  .push  	    (axi_slv_awvalid & axi_slv_awready   ),
                  .push_id     	(`AXI_ID_WIDTH'h0      ),
                  .push_ptr    	(wr_ptr_set     ),
                  .pop  	    (axi_slv_wvalid & axi_slv_wready  ),
                  .pop_id    	(`AXI_ID_WIDTH'h0      ),
                  .pop_last  	(axi_slv_wlast  ),
                  .order_ptr   	(    ),
                  .order_bits  	(wr_ptr_data    )
              );

    // -----------------------------------------------------------------
    // Write Response Order Control
    // -----------------------------------------------------------------
    axi_order #(
                  .OST_DEPTH 	(OST_DEPTH  ),
                  .ID_WIDTH  	(`AXI_ID_WIDTH))
              u_axi_id_order(
                  .clk        	(clk         ),
                  .rst_n      	(rst_n       ),
                  .push  	    (axi_slv_awvalid & axi_slv_awready   ),
                  .push_id     	(axi_slv_awid   ),
                  .push_ptr    	(wr_ptr_set     ),
                  .pop  	    (axi_slv_bvalid & axi_slv_bready  ),
                  .pop_id    	(axi_slv_bid    ),
                  .pop_last  	(1'b1   ),  // bresp only once
                  .order_ptr   	(),
                  .order_bits  	(wr_order_bits  )
              );

    // ------------------------------------------------------------------
    // Output signals
    // ------------------------------------------------------------------
    assign axi_slv_awready = ~wr_buff_full;

    // AXI Slave Write Data Channel
    assign axi_slv_wready = 1'b1;

    // AXI Slave Write Response Channel
    assign axi_slv_bid = wr_id_buff_r[wr_ptr_result];
    assign axi_slv_bresp = wr_resp_buff_r[wr_ptr_result];
    assign axi_slv_buser = wr_user_buff_r[wr_ptr_result];
    assign axi_slv_bvalid = wr_valid_buff_r[wr_ptr_result] & wr_result_buff_r[wr_ptr_result];

endmodule
