module axi_slv #(
        parameter OST_DEPTH = 16
    )(
        input clk,
        input rst_n,

        // AXI Master Read Address Channel
        input [`AXI_ID_WIDTH-1:0] axi_slv_arid,
        input [`AXI_ADDR_WIDTH-1:0] axi_slv_araddr,
        input [`AXI_LEN_WIDTH-1:0] axi_slv_arlen,
        input [`AXI_SIZE_WIDTH -1:0] axi_slv_arsize,
        input [`AXI_BURST_WIDTH-1:0] axi_slv_arburst,
        input axi_slv_arvalid,
        output axi_slv_arready,

        // AXI Master Read Data Channel
        output [`AXI_ID_WIDTH-1:0] axi_slv_rid,
        output [`AXI_DATA_WIDTH-1:0] axi_slv_rdata,
        output [`AXI_RESP_WIDTH-1:0] axi_slv_rresp,
        output axi_slv_rlast,
        output axi_slv_rvalid,
        input axi_slv_rready
    );
    localparam MAX_BURST_LEN = 8;                          // Maximum burst length
    localparam BURST_CNT_WIDTH = $clog2(MAX_BURST_LEN+1);   // Width of burst counter
    localparam REG_ADDR = 16'h0;                            // Default register address
    localparam OST_CNT_WIDTH = $clog2(OST_DEPTH + 1);       // Width of outstanding transaction counter
    localparam MAX_GET_DATA_DLY = `AXI_DATA_GET_CNT_WIDTH'h18;      // Outstanding counter width

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------
    // FSM registers
    wire rd_buff_set;      // Buffer set condition
    wire rd_buff_clr;      // Buffer clear condition
    wire rd_buff_full;     // Buffer full flag

    reg rd_valid_buff_r [OST_DEPTH-1:0];    // Valid buffer register
    reg rd_result_buff_r [OST_DEPTH-1:0];   // Result buffer register
    reg rd_comp_buff_r [OST_DEPTH-1:0];     // Completion buffer register
    reg rd_clear_buff_r [OST_DEPTH-1:0];  // Clear buffer register

    // arrays -> registers
    reg [OST_DEPTH-1:0] rd_valid_bits;
    wire [OST_DEPTH-1:0] rd_set_bits;
    reg [OST_DEPTH-1:0] rd_clear_bits;
    reg [OST_DEPTH-1:0] rd_result_bits;
    wire [OST_DEPTH-1:0] rd_order_bits;

    // Read pointers
    wire [OST_CNT_WIDTH-1:0] rd_ptr_set_r;
    wire [OST_CNT_WIDTH-1:0] rd_ptr_clr_r;
    wire [OST_CNT_WIDTH-1:0] rd_ptr_result_r;

    // Read Address buffers
    reg [`AXI_LEN_WIDTH-1:0] rd_curr_index_r [OST_DEPTH-1:0];       // Current read index
    reg [`AXI_ID_WIDTH-1:0] rd_id_buff_r [OST_DEPTH-1:0];           // AXI ID buffer
    reg [`AXI_ADDR_WIDTH-1:0] rd_addr_buff_r [OST_DEPTH-1:0];       // AXI Address buffer
    reg [`AXI_LEN_WIDTH-1:0] rd_len_buff_r [OST_DEPTH-1:0];         // AXI Length buffer
    reg [`AXI_SIZE_WIDTH-1:0] rd_size_buff_r [OST_DEPTH-1:0];       // AXI Size buffer
    reg [`AXI_BURST_WIDTH-1:0] rd_burst_buff_r [OST_DEPTH-1:0];     // AXI Burst type buffer

    // Read Data buffers
    reg [MAX_BURST_LEN-1:0] rd_data_vld_r [OST_DEPTH-1:0];              // Read data valid flag buffer
    reg [MAX_BURST_LEN*`AXI_DATA_WIDTH-1:0] rd_data_buff_r [OST_DEPTH-1:0];       // Read data buffer
    reg [BURST_CNT_WIDTH-1:0] rd_data_cnt_r [OST_DEPTH-1:0];            // Read data counter buffer
    reg [`AXI_RESP_WIDTH-1:0] rd_resp_buff_r [OST_DEPTH-1:0];           // Read response buffer
    reg [OST_DEPTH-1:0] rd_resp_err;        // Read response error flag

    wire rd_req_en;         // Read address request handshake(valid & ready)
    wire rd_result_en;      // Read data result handshake(valid & ready)
    wire rd_result_id;      // Read result ID
    wire rd_dec_miss;       // Address decode miss flag
    wire rd_result_last;    // Last read result flag
    wire rd_data_get [OST_DEPTH-1:0];      // Data fetch condition (counter max)
    reg [`AXI_DATA_GET_CNT_WIDTH-1:0] rd_data_get_cnt [OST_DEPTH-1:0];   // Data fetch counter condition
    // wire rd_data_get_cnt_en [OST_DEPTH-1:0];    // Data fetch counter enable
    wire rd_data_err [OST_DEPTH-1:0];      // Data error flag (simulated)

    // burst address signals
    wire [`AXI_ADDR_WIDTH-1:0] rd_start_addr [OST_DEPTH-1:0];       // Start address of burst
    wire [`AXI_LEN_WIDTH-1:0] rd_burst_len [OST_DEPTH-1:0];         // Length of burst (caution: the difference between rd_burst_len and rd_len_buff_r in the logical judgment!!!)
    wire [(1 << `AXI_SIZE_WIDTH)-1:0] rd_number_bytes [OST_DEPTH-1:0];     // Number of bytes per transfer
    wire [`AXI_ADDR_WIDTH-1:0] rd_wrap_boundary [OST_DEPTH-1:0];    // Wrap boundary address
    wire [`AXI_ADDR_WIDTH-1:0] rd_aligned_addr [OST_DEPTH-1:0];     // Aligned address
    wire rd_wrap_done  [OST_DEPTH-1:0];                             // Wrap happened flag
    reg rd_wrap_done_r [OST_DEPTH-1:0];                             // Wrap happened flag register
    reg [`AXI_ADDR_WIDTH-1:0] rd_curr_addr_r [OST_DEPTH-1:0];       // Current address register

    // ----------------------------------------------------------------
    // Pointer Logic
    // ----------------------------------------------------------------
    axi_arbit #(
                  .ARB_WIDTH 	(OST_DEPTH  ))
              u_rd_set_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(rd_set_bits    ),
                  .sche_en   	(rd_buff_set    ),
                  .pointer_o 	(rd_ptr_set_r  )
              );

    axi_arbit #(
                  .ARB_WIDTH 	(OST_DEPTH  ))
              u_rd_clr_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(rd_clear_bits    ),
                  .sche_en   	(rd_buff_clr    ),
                  .pointer_o 	(rd_ptr_clr_r  )
              );

    axi_arbit #(
                  .ARB_WIDTH 	(OST_DEPTH  ))
              u_rd_result_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(rd_result_bits & rd_order_bits),
                  .sche_en   	(rd_result_en    ),
                  .pointer_o 	(rd_ptr_result_r  )
              );

    // ----------------------------------------------------------------
    // Main Control
    // ----------------------------------------------------------------
    // array -> register conversion
    always @(*) begin: Get_Clear_Vectors
        integer i;
        rd_clear_bits = {OST_DEPTH{1'b0}};
        for(i=0; i<OST_DEPTH; i=i+1) begin
            rd_clear_bits[i] = rd_clear_buff_r[i];
        end
    end

    always @(*) begin: Get_Result_Vectors
        integer i;
        rd_result_bits = {OST_DEPTH{1'b0}};
        for (i=0;i < OST_DEPTH; i=i+1) begin
            rd_result_bits[i] = rd_result_buff_r[i];
        end
    end

    always @(*) begin: Get_Valid_Vectors
        integer i;
        rd_valid_bits = {OST_DEPTH{1'b0}};
        for (i=0;i < OST_DEPTH; i=i+1) begin
            rd_valid_bits[i] = rd_valid_buff_r[i];
        end
    end
    assign rd_buff_full = &rd_valid_bits;                       // Buffer full if valid bits all set
    assign rd_set_bits = ~rd_valid_bits;   // Set bits are where valid bits are 0

    assign rd_buff_set = axi_slv_arvalid & axi_slv_arready;   // Read request handshake
    assign rd_buff_clr = rd_valid_buff_r[rd_ptr_clr_r] & ~rd_result_buff_r[rd_ptr_clr_r] & ~rd_comp_buff_r[rd_ptr_clr_r]; // Clear buffer if valid and no pending operations

    assign rd_dec_miss = 1'b0;                              // Address decode miss
    assign rd_result_en = axi_slv_rvalid & axi_slv_rready;  // Read result handshake
    assign rd_result_id = axi_slv_rid;                      // Read result ID
    assign rd_result_last = axi_slv_rlast;                  // Last read result

    genvar i;
    generate
        for (i=0; i<OST_DEPTH; i=i+1) begin: OST_BUFFER_FSM
            // FSM: rd_valid_buff_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_valid_buff_r[i] <= #`DLY 1'b0;
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_valid_buff_r[i] <= #`DLY 1'b1;
                end
                else if(rd_buff_clr && (i == rd_ptr_clr_r)) begin
                    rd_valid_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // FSM: rd_result_buff_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_result_buff_r[i] <= #`DLY 1'b0;
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_result_buff_r[i] <= #`DLY rd_dec_miss ? 1'b1 : 1'b0;   // Set result buffer on decode miss, quick rvalid
                end
                else if(rd_result_en && ~rd_result_last && (i == rd_ptr_result_r) && rd_data_vld_r[i][rd_data_cnt_r[i]+1]) begin    // On non-last result and next data valid
                    rd_result_buff_r[i] <= #`DLY 1'b1;    // Keep result buffer set on non-last result (transfer optimization)
                end
                else if(rd_data_get[i]) begin   // wait data get
                    rd_result_buff_r[i] <= #`DLY 1'b1;    // Set result buffer on data get
                end
                else if(rd_result_en && (i == rd_ptr_result_r)) begin
                    rd_result_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // FSM: rd_comp_buff_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_comp_buff_r[i] <= #`DLY 1'b0;
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_comp_buff_r[i] <= #`DLY 1'b1;
                end
                else if(rd_result_en && rd_result_last && (i == rd_ptr_result_r)) begin
                    rd_comp_buff_r[i] <= #`DLY 1'b0;
                end
            end

            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_clear_buff_r[i] <= #`DLY 1'b0;
                end
                else begin
                    rd_clear_buff_r[i] <= #`DLY rd_valid_buff_r[i] & ~rd_result_buff_r[i] & ~rd_comp_buff_r[i];
                end
            end
        end
    endgenerate

    // ----------------------------------------------------------------
    // RESP ID ORDER CONTROL
    // ----------------------------------------------------------------
    axi_idorder #(
                    .OST_DEPTH 	(OST_DEPTH  ),
                    .ID_WIDTH  	(`AXI_ID_WIDTH)   )
                u_axi_idorder(
                    .clk        	(clk         ),
                    .rst_n      	(rst_n       ),
                    .req_valid  	(axi_slv_arvalid   ),
                    .req_ready  	(axi_slv_arready   ),
                    .req_id     	(axi_slv_arid      ),
                    .req_ptr    	(rd_ptr_set_r     ),
                    .resp_valid 	(axi_slv_rvalid  ),
                    .resp_ready 	(axi_slv_rready  ),
                    .resp_id    	(axi_slv_rid     ),
                    .resp_last  	(axi_slv_rlast   ),
                    .resp_ptr   	(    ),
                    .resp_bits  	(rd_order_bits   )
                );


    // ----------------------------------------------------------------
    // Read Address Buffer
    // ----------------------------------------------------------------
    generate
        for(i=0;
                i<OST_DEPTH;
                i=i+1) begin: RD_ADDR_BUFFER_GEN
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_id_buff_r[i] <= #`DLY {`AXI_ID_WIDTH{1'b0}};
                    rd_addr_buff_r[i] <= #`DLY {`AXI_ADDR_WIDTH{1'b0}};
                    rd_len_buff_r[i] <= #`DLY {`AXI_LEN_WIDTH{1'b0}};
                    rd_size_buff_r[i] <= #`DLY {`AXI_SIZE_WIDTH{1'b0}};
                    rd_burst_buff_r[i] <= #`DLY {`AXI_BURST_WIDTH{1'b0}};
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin  // On read request handshake
                    rd_id_buff_r[i] <= #`DLY axi_slv_arid;
                    rd_addr_buff_r[i] <= #`DLY axi_slv_araddr;
                    rd_len_buff_r[i] <= #`DLY axi_slv_arlen;
                    rd_size_buff_r[i] <= #`DLY axi_slv_arsize;
                    rd_burst_buff_r[i] <= #`DLY axi_slv_arburst;
                end
            end
        end
    endgenerate

    // ----------------------------------------------------------------
    // Burst Address Calculation
    // ----------------------------------------------------------------
    generate
        for(i=0;
                i<OST_DEPTH;
                i=i+1) begin: BURST_CTRL
            assign rd_start_addr[i]
                   = rd_addr_buff_r[i];
            assign rd_number_bytes[i] = 1 << rd_size_buff_r[i];
            assign rd_burst_len[i] = rd_len_buff_r[i] + 1;
            assign rd_aligned_addr[i] = rd_start_addr[i] / rd_number_bytes[i] * rd_number_bytes[i]; // Aligned address calculation
            assign rd_wrap_boundary[i] = rd_start_addr[i] / (rd_burst_len[i] * rd_number_bytes[i]) * (rd_burst_len[i] * rd_number_bytes[i]);    // Wrap boundary calculation
            assign rd_wrap_done[i] = (rd_curr_addr_r[i] + rd_number_bytes[i]) == (rd_wrap_boundary[i] + (rd_burst_len[i] * rd_number_bytes[i]));    // Wrap done condition

            // rd_curr_index_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_curr_index_r[i] <= #`DLY {`AXI_LEN_WIDTH{1'b0}};
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_curr_index_r[i] <= #`DLY rd_dec_miss ? rd_burst_len[i] : `AXI_LEN_WIDTH'h1;   // Set index based on decode miss, quick rlast
                end
                else if(rd_result_en && rd_result_last && (i == rd_ptr_result_r)) begin
                    rd_curr_index_r[i] <= #`DLY {`AXI_LEN_WIDTH{1'b0}};         // Clear index on last result
                end
                else if(rd_data_get[i]) begin
                    rd_curr_index_r[i] <= #`DLY rd_curr_index_r[i] + 1'b1;    // Increment read index
                end
            end

            // rd_wrap_done_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_wrap_done_r[i] <= #`DLY 1'b0;
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_wrap_done_r[i] <= #`DLY 1'b0; // Clear on buffer set
                end
                else if(rd_data_get[i]) begin
                    rd_wrap_done_r[i] <= #`DLY rd_wrap_done[i] | rd_wrap_done_r[i]; // Capture wrap done
                end
            end

            // rd_curr_addr_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_curr_addr_r[i] <= #`DLY {`AXI_ADDR_WIDTH{1'b0}};
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_curr_addr_r[i] <= #`DLY axi_slv_araddr; // Set start address on buffer set
                end
                else if(rd_data_get[i]) begin
                    case (rd_burst_buff_r[i])
                        `AXI_BURST_FIXED:
                            rd_curr_addr_r[i] <= #`DLY rd_curr_addr_r[i]; // Fixed address
                        `AXI_BURST_INCR:
                            rd_curr_addr_r[i] <= #`DLY rd_aligned_addr[i] + (rd_curr_index_r[i] * rd_number_bytes[i]); // Increment address
                        `AXI_BURST_WRAP: begin
                            if(rd_wrap_done[i])
                                rd_curr_addr_r[i] <= #`DLY rd_wrap_boundary[i]; // first wrap back to boundary
                            else if(rd_wrap_done_r[i])
                                rd_curr_addr_r[i] <= #`DLY rd_addr_buff_r[i] + (rd_curr_index_r[i] * rd_number_bytes[i]) - (rd_burst_len[i] * rd_number_bytes[i]); // wrapped address
                            else
                                rd_curr_addr_r[i] <= #`DLY rd_aligned_addr[i] + (rd_burst_len[i] * rd_number_bytes[i]); // Increment address
                        end
                        default:
                            rd_curr_addr_r[i] <= #`DLY {`AXI_ADDR_WIDTH{1'b0}};
                    endcase
                end
            end
        end
    endgenerate

    // ----------------------------------------------------------------
    // Read Data Buffer
    // ----------------------------------------------------------------
    generate
        for (i=0;
                i<OST_DEPTH;
                i=i+1) begin: RD_DATA_BUFFER_GEN
            // rd_resp_buff_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_resp_buff_r[i] <= #`DLY {`AXI_RESP_WIDTH{1'b0}};
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_resp_buff_r[i] <= #`DLY rd_dec_miss ? `AXI_RESP_DECERR : `AXI_RESP_OKAY; // Set response on decode miss
                end
                else if(rd_data_get[i]) begin
                    rd_resp_buff_r[i] <= #`DLY rd_data_err[i] ? `AXI_RESP_SLVERR : `AXI_RESP_OKAY; // Set response on data error
                end
            end
            // rd_data_cnt_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(rd_result_en && (i == rd_ptr_result_r)) begin
                    rd_data_cnt_r[i] <= #`DLY rd_data_cnt_r[i] + 1'b1;
                end
            end
            // rd_data_buff_r and rd_data_vld_r
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_data_buff_r[i] <= #`DLY {`AXI_DATA_WIDTH{1'b0}};
                    rd_data_vld_r[i] <= #`DLY {MAX_BURST_LEN*`AXI_DATA_WIDTH{1'b0}};
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_data_buff_r[i] <= #`DLY {MAX_BURST_LEN*`AXI_DATA_WIDTH{1'b0}};
                    rd_data_vld_r[i] <= #`DLY {MAX_BURST_LEN{1'b0}};
                end
                else if(rd_data_get[i]) begin
                    rd_data_buff_r[i][((rd_curr_index_r[i]-1)*`AXI_DATA_WIDTH) +: `AXI_DATA_WIDTH] <= #`DLY {{`AXI_DATA_WIDTH-`AXI_ID_WIDTH-`AXI_ADDR_WIDTH{1'b0}},rd_id_buff_r[i],rd_curr_addr_r[i]};
                    rd_data_vld_r[i][rd_curr_index_r[i]-1] <= #`DLY 1'b1;
                end
            end
        end
    endgenerate
    // ----------------------------------------------------------------
    // Simulate the data reading process
    // ----------------------------------------------------------------
    generate
        for(i=0;
                i<OST_DEPTH;
                i=i+1) begin: RD_DATA_PROC_SIM
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h0;
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin   // On buffer set
                    rd_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h1;
                end
                else if(rd_data_get[i] && (rd_curr_index_r[i] < rd_burst_len[i])) begin     // Continue fetching data if not last
                    rd_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h1;
                end
                else if(rd_data_get_cnt[i] == MAX_GET_DATA_DLY) begin
                    rd_data_get_cnt[i] <= #`DLY `AXI_DATA_GET_CNT_WIDTH'h0;
                end
                else if(rd_data_get_cnt[i] > `AXI_DATA_GET_CNT_WIDTH'h0) begin
                    rd_data_get_cnt[i] <= #`DLY rd_data_get_cnt[i] + 1'b1;
                end
            end

            assign rd_data_get[i] = rd_valid_buff_r[i] & (rd_data_get_cnt[i] == MAX_GET_DATA_DLY - rd_id_buff_r[i]);    // Data get condition
            assign rd_data_err[i] = (rd_id_buff_r[i] == `AXI_ID_WIDTH'hF) & (rd_curr_index_r[i] == rd_burst_len[i]);    // Simulated data error when ID is max and last transfer
        end
    endgenerate

    // ----------------------------------------------------------------
    // output signals
    // ----------------------------------------------------------------
    // AXI Slave Read Address Channel
    assign axi_slv_arready = ~rd_buff_full;                 // Ready when buffer not full
    // AXI Slave Read Data Channel
    assign axi_slv_rid = rd_id_buff_r[rd_ptr_result_r];      // Read ID output
    assign axi_slv_rdata = rd_data_buff_r[rd_ptr_result_r][rd_data_cnt_r[rd_ptr_result_r]*`AXI_DATA_WIDTH +:
            `AXI_DATA_WIDTH];      // Read data output
    assign axi_slv_rresp = rd_resp_buff_r[rd_ptr_result_r];      // Read response output
    assign axi_slv_rvalid = rd_valid_buff_r[rd_ptr_result_r] & rd_result_buff_r[rd_ptr_result_r];   // Read valid signal
    assign axi_slv_rlast = axi_slv_rvalid & (rd_data_cnt_r[rd_ptr_result_r] == rd_len_buff_r[rd_ptr_result_r]);  // Last read flag: when valid and last index

endmodule
