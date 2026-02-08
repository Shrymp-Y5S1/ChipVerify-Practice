module axi_mst_wr #(
        parameter OST_DEPTH = 16
    )(
        input clk,
        input rst_n,
        input wr_en,
        output wr_req_finish,    // Request finish signal

        // AXI Master Write Address Channel
        output [`AXI_ID_WIDTH-1:0] axi_mst_awid,
        output [`AXI_ADDR_WIDTH-1:0] axi_mst_awaddr,
        output [`AXI_LEN_WIDTH-1:0] axi_mst_awlen,
        output [`AXI_SIZE_WIDTH -1:0] axi_mst_awsize,
        output [`AXI_BURST_WIDTH-1:0] axi_mst_awburst,
        output [`AXI_USER_WIDTH-1:0] axi_mst_awuser,
        output axi_mst_awvalid,
        input axi_mst_awready,

        // AXI Master Write Data Channel
        output [`AXI_DATA_WIDTH-1:0] axi_mst_wdata,
        output [(`AXI_DATA_WIDTH >> 3)-1:0] axi_mst_wstrb,
        output [`AXI_USER_WIDTH-1:0] axi_mst_wuser,
        output axi_mst_wlast,
        output axi_mst_wvalid,
        input axi_mst_wready,

        // AXI Master Write Response Channel
        input [`AXI_ID_WIDTH-1:0] axi_mst_bid,
        input [`AXI_RESP_WIDTH-1:0] axi_mst_bresp,
        input [`AXI_USER_WIDTH-1:0] axi_mst_buser,
        input axi_mst_bvalid,
        output axi_mst_bready
    );

    localparam MAX_BURST_LEN = 8;
    localparam BURST_CNT_WIDTH = $clog2(MAX_BURST_LEN+1);
    localparam OST_CNT_WIDTH = $clog2(OST_DEPTH + 1);
    localparam MAX_REQ_NUM = 16;
    localparam REQ_CNT_WIDTH = $clog2(MAX_REQ_NUM + 1);
    localparam MAX_GET_DATA_DLY = `AXI_DATA_GET_CNT_WIDTH'h1c;

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------
    // control and state signals
    wire wr_buff_set;   // decision and config
    wire wr_buff_clr;
    wire wr_buff_full;
    reg wr_buff_set_r;  // start subsequent process

    reg wr_valid_buff_r [OST_DEPTH-1:0];
    reg wr_req_buff_r [OST_DEPTH-1:0];
    reg wr_data_ready_r [OST_DEPTH-1:0];
    reg wr_comp_buff_r [OST_DEPTH-1:0];
    reg wr_clear_buff_r [OST_DEPTH-1:0];

    // bit vectors
    reg [OST_DEPTH-1:0] wr_valid_bits;
    wire [OST_DEPTH-1:0] wr_set_bits;
    reg [OST_DEPTH-1:0] wr_req_bits;
    reg [OST_DEPTH-1:0] wr_clear_bits;

    // Write pointers
    wire [OST_CNT_WIDTH-1:0] wr_ptr_set;    // decision and config
    wire [OST_CNT_WIDTH-1:0] wr_ptr_clr;
    wire [OST_CNT_WIDTH-1:0] wr_ptr_req;
    wire [OST_CNT_WIDTH-1:0] wr_ptr_data;
    wire [OST_CNT_WIDTH-1:0] wr_ptr_result;
    reg [OST_CNT_WIDTH-1:0] wr_ptr_set_r;   // start subsequent process

    // Write request buffers
    reg [`AXI_LEN_WIDTH-1:0] wr_curr_index_r [OST_DEPTH-1:0];
    reg [`AXI_ID_WIDTH-1:0] wr_id_buff_r [OST_DEPTH-1:0];
    reg [`AXI_ADDR_WIDTH-1:0] wr_addr_buff_r [OST_DEPTH-1:0];
    reg [`AXI_LEN_WIDTH-1:0] wr_len_buff_r [OST_DEPTH-1:0];
    reg [`AXI_SIZE_WIDTH-1:0] wr_size_buff_r [OST_DEPTH-1:0];
    reg [`AXI_BURST_WIDTH-1:0] wr_burst_buff_r [OST_DEPTH-1:0];
    reg [`AXI_USER_WIDTH-1:0] wr_user_buff_r [OST_DEPTH-1:0];

    reg [`AXI_ADDR_WIDTH-1:0] wr_addr_buff [OST_DEPTH-1:0];
    reg [`AXI_LEN_WIDTH-1:0] wr_len_buff [OST_DEPTH-1:0];
    reg [`AXI_SIZE_WIDTH-1:0] wr_size_buff [OST_DEPTH-1:0];
    reg [`AXI_BURST_WIDTH-1:0] wr_burst_buff [OST_DEPTH-1:0];

    // Write data and response buffers
    reg [MAX_BURST_LEN-1:0] wr_data_vld_r [OST_DEPTH-1:0];
    reg [`AXI_DATA_WIDTH*MAX_BURST_LEN-1:0] wr_data_buff_r [OST_DEPTH-1:0];
    reg [(`AXI_DATA_WIDTH >> 3)*MAX_BURST_LEN-1:0] wr_strb_buff_r [OST_DEPTH-1:0];
    reg [BURST_CNT_WIDTH-1:0] wr_data_cnt_r [OST_DEPTH-1:0];
    reg [`AXI_RESP_WIDTH-1:0] wr_resp_buff_r [OST_DEPTH-1:0];
    wire [OST_DEPTH-1:0] wr_resp_err;

    // Write handshake signals
    wire wr_req_en;
    wire wr_data_en;
    wire wr_data_last;

    // Request counter
    reg [REQ_CNT_WIDTH-1:0] wr_req_cnt_r;

    // Write response
    wire wr_result_en;
    wire [`AXI_ID_WIDTH-1:0] wr_result_id;

    // address calculation registers
    reg [`AXI_ADDR_WIDTH-1:0] wr_curr_addr_r [OST_DEPTH-1:0];
    reg wr_wrap_done_r [OST_DEPTH-1:0];
    wire [`AXI_ADDR_WIDTH-1:0] wr_start_addr [OST_DEPTH-1:0];
    wire [`AXI_LEN_WIDTH-1:0] wr_burst_len [OST_DEPTH-1:0];
    wire [(1<<`AXI_SIZE_WIDTH)-1:0] wr_number_bytes [OST_DEPTH-1:0];
    wire [`AXI_ADDR_WIDTH-1:0] wr_wrap_boundary [OST_DEPTH-1:0];
    wire [`AXI_ADDR_WIDTH-1:0] wr_aligned_addr [OST_DEPTH-1:0];
    wire wr_wrap_done [OST_DEPTH-1:0];

    // Simulation write data generation
    reg [`AXI_DATA_GET_CNT_WIDTH-1:0] wr_data_get_cnt [OST_DEPTH-1:0];
    wire wr_data_get [OST_DEPTH-1:0];
    wire wr_data_err [OST_DEPTH-1:0];

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
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_buff_set_r <= #`DLY 1'b0;
            wr_ptr_set_r <= #`DLY {OST_CNT_WIDTH{1'b0}};
        end
        else begin
            wr_buff_set_r <= #`DLY wr_buff_set;
            wr_ptr_set_r <= #`DLY wr_ptr_set;
        end
    end

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
              u_wr_req_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(wr_req_bits    ),
                  .sche_en   	(wr_req_en    ),
                  .pointer_o 	(wr_ptr_req  )
              );

    // ----------------------------------------------------------------
    // Main Control
    // ----------------------------------------------------------------
    // array -> register conversion
    always @(*) begin: MST_WR_VALID_VEC
        integer i;
        wr_valid_bits = {OST_DEPTH{1'b0}};
        for (i=0;i < OST_DEPTH; i=i+1) begin
            wr_valid_bits[i] = wr_valid_buff_r[i];
        end
    end

    always @(*) begin: MST_WR_REQ_VEC
        integer i;
        wr_req_bits = {OST_DEPTH{1'b0}};
        for(i=0; i<OST_DEPTH; i=i+1) begin
            wr_req_bits[i] = wr_req_buff_r[i];
        end
    end

    always @(*) begin: MST_WR_CLEAR_VEC
        integer i;
        wr_clear_bits = {OST_DEPTH{1'b0}};
        for(i=0; i<OST_DEPTH; i=i+1) begin
            wr_clear_bits[i] = wr_clear_buff_r[i];
        end
    end

    assign wr_buff_full = &wr_valid_bits;
    assign wr_buff_set = ~wr_buff_full & wr_en;
    assign wr_set_bits = ~wr_valid_bits;

    assign wr_buff_clr = wr_valid_buff_r[wr_ptr_clr] & ~wr_req_buff_r[wr_ptr_clr] & ~wr_comp_buff_r[wr_ptr_clr];

    assign wr_req_en = axi_mst_awvalid & axi_mst_awready;
    assign wr_data_en = axi_mst_wvalid & axi_mst_wready;
    assign wr_data_last = axi_mst_wlast;
    assign wr_result_en = axi_mst_bvalid & axi_mst_bready;

    genvar i;
    generate
        for (i=0; i<OST_DEPTH; i=i+1) begin: MST_WR_BUFFERS
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

            // Request Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_req_buff_r[i] <= #`DLY 1'b0;
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_req_buff_r[i] <= #`DLY 1'b1;
                end
                else if(wr_req_en && (i == wr_ptr_req)) begin
                    wr_req_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // Data ready Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_data_ready_r[i] <= #`DLY 1'b0;
                end
                else begin
                    if(wr_buff_set && (i == wr_ptr_set)) begin
                        wr_data_ready_r[i] <= #`DLY 1'b0;
                    end
                    else if(wr_data_en && ~wr_data_last && (wr_ptr_data == i) && wr_data_vld_r[i][wr_data_cnt_r[i]+1]) begin
                        // 当前正在传数据，且下一拍数据也已经就绪
                        wr_data_ready_r[i] <= #`DLY 1'b1;
                    end
                    else if(wr_data_get[i]) begin
                        wr_data_ready_r[i] <= #`DLY 1'b1;
                    end
                    else if(wr_data_en && (wr_ptr_data == i)) begin
                        wr_data_ready_r[i] <= #`DLY 1'b0;
                    end
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
                else if(wr_result_en & (wr_ptr_result == i)) begin
                    wr_comp_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // Clear Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_clear_buff_r[i] <= #`DLY 1'b0;
                end
                else begin
                    wr_clear_buff_r[i] <= #`DLY wr_valid_buff_r[i] & ~wr_req_buff_r[i] & ~wr_comp_buff_r[i];
                end
            end

            // ----------------------------------------------------------------
            // AXI AW Payload Buffer
            // ----------------------------------------------------------------
            always @(*) begin
                case (wr_req_cnt_r[1:0])    // Use request counter to generate different address patterns for testing
                    2'b00: begin    // INCR, LEN=4
                        wr_addr_buff[i] = `AXI_ADDR_WIDTH'h0;
                        wr_len_buff[i] = `AXI_LEN_WIDTH'h3;
                        wr_size_buff[i] = `AXI_SIZE_4_BYTE;
                        wr_burst_buff[i] = `AXI_BURST_INCR;
                    end
                    2'b01: begin    // INCR, LEN=4
                        wr_addr_buff[i] = wr_req_cnt_r * `AXI_ADDR_WIDTH'h10;
                        wr_len_buff[i] = `AXI_LEN_WIDTH'h3;
                        wr_size_buff[i] = `AXI_SIZE_4_BYTE;
                        wr_burst_buff[i] = `AXI_BURST_INCR;
                    end
                    2'b10: begin    // WRAP, LEN=4
                        wr_addr_buff[i] = `AXI_ADDR_WIDTH'h24;
                        wr_len_buff[i] = `AXI_LEN_WIDTH'h3;
                        wr_size_buff[i] = `AXI_SIZE_4_BYTE;
                        wr_burst_buff[i] = `AXI_BURST_WRAP;
                    end
                    2'b11: begin    // FIXED, LEN=4
                        wr_addr_buff[i] = `AXI_ADDR_WIDTH'h30;
                        wr_len_buff[i] = `AXI_LEN_WIDTH'h3;
                        wr_size_buff[i] = `AXI_SIZE_4_BYTE;
                        wr_burst_buff[i] = `AXI_BURST_FIXED;
                    end
                    default: begin    // INCR, LEN=4
                        wr_addr_buff[i] = `AXI_ADDR_WIDTH'h80;
                        wr_len_buff[i] = `AXI_LEN_WIDTH'h3;
                        wr_size_buff[i] = `AXI_SIZE_4_BYTE;
                        wr_burst_buff[i] = `AXI_BURST_INCR;
                    end
                endcase
            end

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
                    wr_id_buff_r[i] <= #`DLY wr_req_cnt_r[`AXI_ID_WIDTH-1:0];
                    wr_addr_buff_r[i] <= #`DLY wr_addr_buff[i];
                    wr_len_buff_r[i] <= #`DLY wr_len_buff[i];
                    wr_size_buff_r[i] <= #`DLY wr_size_buff[i];
                    wr_burst_buff_r[i] <= #`DLY wr_burst_buff[i];
                    wr_user_buff_r[i] <=#`DLY wr_req_cnt_r;
                end
            end

            // ----------------------------------------------------------------
            // Address Calculation
            // ----------------------------------------------------------------
            assign wr_start_addr[i] = (wr_buff_set && (i == wr_ptr_set)) ? wr_addr_buff[i] : wr_addr_buff_r[i];
            assign wr_number_bytes[i] = (wr_buff_set && (i == wr_ptr_set)) ? 1 << wr_size_buff[i] : 1 << wr_size_buff_r[i];
            assign wr_burst_len[i] = (wr_buff_set && (i == wr_ptr_set)) ? wr_len_buff[i] + 1 : wr_len_buff_r[i] + 1;
            assign wr_aligned_addr[i] = wr_start_addr[i] / wr_number_bytes[i] * wr_number_bytes[i];
            assign wr_wrap_boundary[i] = wr_start_addr[i] / (wr_burst_len[i] * wr_number_bytes[i]) * (wr_burst_len[i] * wr_number_bytes[i]);
            assign wr_wrap_done[i] = (wr_curr_addr_r[i] + wr_number_bytes[i]) == (wr_wrap_boundary[i] + (wr_burst_len[i] * wr_number_bytes[i]));

            // Write index calculation
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_curr_index_r[i] <= #`DLY `AXI_LEN_WIDTH'h0;
                end
                else if(wr_buff_set_r && (i == wr_ptr_set_r)) begin
                    wr_curr_index_r[i] <= #`DLY `AXI_LEN_WIDTH'h1;
                end
                else if(wr_data_en && wr_data_last && (i == wr_ptr_data)) begin
                    wr_curr_index_r[i] <= #`DLY `AXI_LEN_WIDTH'h0;
                end
                else if(wr_data_get[i]) begin
                    wr_curr_index_r[i] <= #`DLY wr_curr_index_r[i] + 1'b1;
                end
            end

            // Write address wrap control
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_wrap_done_r[i] <= #`DLY 1'b0;
                end
                else if(wr_buff_set_r && (i == wr_ptr_set_r)) begin
                    wr_wrap_done_r[i] <= #`DLY 1'b0;
                end
                else if(wr_data_get[i]) begin
                    wr_wrap_done_r[i] <= #`DLY wr_wrap_done[i] | wr_wrap_done_r[i]; // if wrapped, keep done until next burst
                end
            end

            // Current address calculation（real master write didn't need）
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_curr_addr_r[i] <= #`DLY `AXI_ADDR_WIDTH'h0;
                end
                else if(wr_buff_set_r && (i == wr_ptr_set_r)) begin
                    wr_curr_addr_r[i] <= #`DLY wr_start_addr[i];
                end
                else if(wr_data_get[i]) begin
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
            // AXI W Payload Buffer
            // ----------------------------------------------------------------
            // Write Data Counter
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(wr_buff_set_r && (wr_ptr_set_r == i)) begin
                    wr_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(wr_data_en && (wr_ptr_data == i)) begin
                    wr_data_cnt_r[i] <= #`DLY wr_data_cnt_r[i] + 1'b1;
                end
            end

            // Write Data Buffer
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_data_buff_r[i] <= #`DLY `AXI_DATA_WIDTH'h0;
                    wr_data_vld_r[i] <= #`DLY {`AXI_DATA_WIDTH*MAX_BURST_LEN{1'b0}};
                    wr_strb_buff_r[i] <= #`DLY {(MAX_BURST_LEN*(`AXI_DATA_WIDTH >> 3)){1'b0}};
                end
                else if(wr_buff_set && (i == wr_ptr_set)) begin
                    wr_data_buff_r[i] <= #`DLY {MAX_BURST_LEN*`AXI_DATA_WIDTH{1'b0}};
                    wr_data_vld_r[i] <= #`DLY {MAX_BURST_LEN{1'b0}};
                    wr_strb_buff_r[i] <= #`DLY {(MAX_BURST_LEN*(`AXI_DATA_WIDTH >> 3)){1'b0}};
                end
                else if(wr_data_get[i]) begin
                    wr_data_buff_r[i][((wr_curr_index_r[i]-1)*`AXI_DATA_WIDTH) +: `AXI_DATA_WIDTH] <= #`DLY {{`AXI_DATA_WIDTH-`AXI_ID_WIDTH-`AXI_ADDR_WIDTH{1'b1}},wr_id_buff_r[i],wr_curr_addr_r[i]};
                    wr_data_vld_r[i][wr_curr_index_r[i]-1] <= #`DLY 1'b1;
                    wr_strb_buff_r[i][(wr_curr_index_r[i]-1)*(`AXI_DATA_WIDTH >> 3) +: (`AXI_DATA_WIDTH >> 3)] <= #`DLY {(`AXI_DATA_WIDTH >> 3){1'b1}} << (wr_curr_index_r[i] - 1); // For testing, use shifting strobe to simulate partial last beat transfer
                end
            end

            // ----------------------------------------------------------------
            // AXI B RESP Buffer
            // ----------------------------------------------------------------
            // Write Response Buffer
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_resp_buff_r[i] <= #`DLY {`AXI_RESP_WIDTH{1'b0}};
                end
                else if(wr_result_en && (wr_ptr_result == i)) begin
                    wr_resp_buff_r[i] <= #`DLY (axi_mst_bresp > wr_resp_buff_r[i]) ? axi_mst_bresp : wr_resp_buff_r[i];
                end
            end

            // Write Response Error Flag
            assign wr_resp_err[i] = (wr_resp_buff_r[i] == `AXI_RESP_SLVERR) | (wr_resp_buff_r[i] == `AXI_RESP_DECERR);

            // ----------------------------------------------------------------
            // Simulate the data fetch delay and potential error for testing
            // ----------------------------------------------------------------
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    wr_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h0;
                end
                else if(wr_buff_set_r && (i == wr_ptr_set_r)) begin   // On buffer set
                    wr_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h1;
                end
                else if(wr_data_get[i] && (wr_curr_index_r[i] < wr_burst_len[i])) begin     // Continue fetching data if not last
                    wr_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h1;
                end
                else if(wr_data_get_cnt[i] == MAX_GET_DATA_DLY) begin
                    wr_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h0;
                end
                else if(wr_data_get_cnt[i] > `AXI_DATA_GET_CNT_WIDTH'h0) begin
                    wr_data_get_cnt[i] <= #`DLY wr_data_get_cnt[i] + 1'b1;
                end
            end

            assign wr_data_get[i] = wr_valid_buff_r[i] & (wr_data_get_cnt[i] == (MAX_GET_DATA_DLY - wr_id_buff_r[i]));    // Data get condition
            assign wr_data_err[i] = (wr_id_buff_r[i] == `AXI_ID_WIDTH'hF) & (wr_curr_index_r[i] == wr_burst_len[i]);    // Simulated data error when ID is max and last transfer

        end
    endgenerate

    // ----------------------------------------------------------------
    // Write Order Control
    // ----------------------------------------------------------------
    // AW channel doesn't carry ID, have to maintain order separately to match with W channel
    axi_order #(
                  .OST_DEPTH 	(OST_DEPTH  ),
                  .ID_WIDTH  	(`AXI_ID_WIDTH))
              u_axi_wr_order(
                  .clk        	(clk         ),
                  .rst_n      	(rst_n       ),
                  .push  	    (axi_mst_awvalid & axi_mst_awready   ),
                  .push_id     	(`AXI_ID_WIDTH'h0      ),
                  .push_ptr    	(wr_ptr_req     ),
                  .pop  	    (axi_mst_wvalid & axi_mst_wready  ),
                  .pop_id    	(`AXI_ID_WIDTH'h0     ),
                  .pop_last  	(axi_mst_wlast   ),
                  .order_ptr   	(wr_ptr_data    ),
                  .order_bits  	(   )
              );

    // ----------------------------------------------------------------
    // RESP ID ORDER CONTROL
    // ----------------------------------------------------------------
    axi_order #(
                  .OST_DEPTH 	(OST_DEPTH  ),
                  .ID_WIDTH  	(`AXI_ID_WIDTH))
              u_axi_id_order(
                  .clk        	(clk         ),
                  .rst_n      	(rst_n       ),
                  .push  	    (axi_mst_awvalid & axi_mst_awready   ),
                  .push_id     	(axi_mst_awid      ),
                  .push_ptr    	(wr_ptr_req     ),
                  .pop  	    (axi_mst_bvalid & axi_mst_bready  ),
                  .pop_id    	(axi_mst_bid     ),
                  .pop_last  	(1'b1   ),  // bresp only once
                  .order_ptr   	(wr_ptr_result    ),
                  .order_bits  	(   )
              );

    // ----------------------------------------------------------------
    // Request Finish Logic
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_req_cnt_r <= #`DLY {REQ_CNT_WIDTH{1'b0}};
        end
        else if(wr_buff_set) begin
            wr_req_cnt_r <= #`DLY wr_req_cnt_r + 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // Output signal assignments
    // ----------------------------------------------------------------

    assign wr_req_finish = (wr_req_cnt_r == MAX_REQ_NUM); // Request finish when reaching max request number

    // AXI Master Write Address Channel
    assign axi_mst_awid = wr_id_buff_r [wr_ptr_req];
    assign axi_mst_awaddr = wr_addr_buff_r [wr_ptr_req];
    assign axi_mst_awlen = wr_len_buff_r [wr_ptr_req];
    assign axi_mst_awsize = wr_size_buff_r [wr_ptr_req];
    assign axi_mst_awburst = wr_burst_buff_r [wr_ptr_req];
    assign axi_mst_awuser = wr_user_buff_r [wr_ptr_req];
    assign axi_mst_awvalid = |wr_req_bits;

    // AXI Master Write Data Channel
    assign axi_mst_wdata = wr_data_buff_r [wr_ptr_data][(wr_data_cnt_r[wr_ptr_data]*`AXI_DATA_WIDTH) +: `AXI_DATA_WIDTH];
    assign axi_mst_wstrb = wr_strb_buff_r [wr_ptr_data][(wr_data_cnt_r[wr_ptr_data]*(`AXI_DATA_WIDTH >> 3)) +: (`AXI_DATA_WIDTH >> 3)];
    assign axi_mst_wuser = wr_user_buff_r [wr_ptr_data];
    assign axi_mst_wlast = axi_mst_wvalid & (wr_data_cnt_r[wr_ptr_data] == wr_len_buff_r[wr_ptr_data]); // Last when data count reaches burst length - 1
    assign axi_mst_wvalid = wr_valid_buff_r[wr_ptr_data] & wr_data_ready_r[wr_ptr_data]; // Valid when data ready and data valid


    // AXI Master Write Response Channel
    assign axi_mst_bready = 1'b1;


endmodule
