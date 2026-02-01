module axi_slv(
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
        output [`AXI_DATA_WIDTH-1:0] axi_slv_rdata,
        output [`AXI_RESP_WIDTH-1:0] axi_slv_rresp,
        output axi_slv_rlast,
        output axi_slv_rvalid,
        input axi_slv_rready
    );
    localparam CLR_CNT_WIDTH = 4;       // Clear counter width
    localparam REG_ADDR = 16'h0;        // Default register address

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------
    // FSM registers
    wire rd_buff_set;      // Buffer set condition
    wire rd_buff_clr;      // Buffer clear condition
    wire rd_buff_full;     // Buffer full flag

    reg rd_valid_buff_r;    // Valid buffer register
    reg rd_result_buff_r;   // Result buffer register
    reg [`AXI_LEN_WIDTH-1:0]rd_curr_index_r; // Current read index

    // Read Address buffers
    reg [`AXI_ID_WIDTH-1:0] rd_id_buff_r;           // AXI ID buffer
    reg [`AXI_ADDR_WIDTH-1:0] rd_addr_buff_r;       // AXI Address buffer
    reg [`AXI_LEN_WIDTH-1:0] rd_len_buff_r;         // AXI Length buffer
    reg [`AXI_SIZE_WIDTH-1:0] rd_size_buff_r;       // AXI Size buffer
    reg [`AXI_BURST_WIDTH-1:0] rd_burst_buff_r;     // AXI Burst type buffer

    // Read Data buffers
    reg [`AXI_DATA_WIDTH-1:0] rd_data_buff_r
        ;       // Read data buffer
    reg [`AXI_RESP_WIDTH-1:0] rd_resp_buff_r;       // Read response buffer

    wire rd_req_en;        // Read address request handshake(valid & ready)
    wire rd_result_en;     // Read data result handshake(valid & ready)
    wire rd_dec_miss;       // Address decode miss flag
    wire rd_result_last;   // Last read result flag
    wire rd_data_get;      // Data fetch condition (counter max)
    wire rd_data_err;      // Data error flag (simulated)

    reg [CLR_CNT_WIDTH-1:0] clr_cnt_r;    // Clear counter for data fetch simulation

    // burst address signals
    wire [`AXI_ADDR_WIDTH-1:0] rd_start_addr;       // Start address of burst
    wire [`AXI_LEN_WIDTH-1:0] rd_burst_len;         // Length of burst (caution: the difference between rd_burst_len and rd_len_buff_r in the logical judgment!!!)
    wire [(1 << `AXI_SIZE_WIDTH)-1:0] rd_number_bytes;     // Number of bytes per transfer
    wire [`AXI_ADDR_WIDTH-1:0] rd_wrap_boundary;    // Wrap boundary address
    wire [`AXI_ADDR_WIDTH-1:0] rd_aligned_addr;     // Aligned address
    wire rd_wrap_done;                              // Wrap happened flag
    reg rd_wrap_done_r;                             // Wrap happened flag register
    reg [`AXI_ADDR_WIDTH-1:0] rd_curr_addr_r;       // Current address register

    // ----------------------------------------------------------------
    // main control
    // ----------------------------------------------------------------
    assign rd_buff_full = &rd_valid_buff_r;                 // Buffer full if valid buffer all set
    assign rd_buff_set = rd_req_en;   // Set buffer on read request handshake
    assign rd_buff_clr = rd_result_en & rd_result_last;     // Clear buffer on last read result

    assign rd_req_en = axi_slv_arvalid & axi_slv_arready;   // Read request handshake
    assign rd_dec_miss = 1'b0;      // Address decode miss
    assign rd_result_en = axi_slv_rvalid & axi_slv_rready;  // Read result handshake
    assign rd_result_last = axi_slv_rlast;                  // Last read result

    // FSM: rd_valid_buff_r
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_valid_buff_r <= #`DLY 1'b0;
        end
        else if(rd_buff_set) begin
            rd_valid_buff_r <= #`DLY 1'b1;
        end
        else if(rd_buff_clr) begin
            rd_valid_buff_r <= #`DLY 1'b0;
        end
    end

    // FSM: rd_result_buff_r and rd_curr_index_r
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_result_buff_r <= #`DLY 1'b0;
            rd_curr_index_r <= #`DLY {`AXI_LEN_WIDTH{1'b0}};
        end
        else if(rd_buff_set) begin  //
            rd_result_buff_r <= #`DLY rd_dec_miss ? 1'b1 : 1'b0;   // Set result buffer on decode miss, quick rvalid
            rd_curr_index_r <= #`DLY rd_dec_miss ? axi_slv_arlen : {`AXI_LEN_WIDTH{1'b0}}; // Set index based on decode miss, quick rlast
        end
        else if(rd_result_en) begin
            rd_result_buff_r <= #`DLY rd_data_get;    // Set result buffer on data fetch condition, clear otherwise
            rd_curr_index_r <= #`DLY rd_curr_index_r + `AXI_LEN_WIDTH'h1;    // Increment read index
        end
        else if(rd_data_get) begin
            rd_result_buff_r <= #`DLY 1'b1;    // Set result buffer on data fetch condition
        end
    end

    // burst address calculation
    assign rd_start_addr = rd_buff_set ? axi_slv_araddr : rd_addr_buff_r; // Capture start address on buffer set
    assign rd_number_bytes = rd_buff_set ? (1 << axi_slv_arsize) : (1 << rd_size_buff_r); // Capture number of bytes on buffer set
    assign rd_burst_len = rd_buff_set ? (axi_slv_arlen + 1'b1) : (rd_len_buff_r + 1); // Capture burst length on buffer set
    assign rd_aligned_addr = rd_start_addr / rd_number_bytes * rd_number_bytes; // Aligned address calculation
    assign rd_wrap_boundary = rd_start_addr / (rd_burst_len * rd_number_bytes) * (rd_burst_len * rd_number_bytes); // Wrap boundary calculation
    assign rd_wrap_done = (rd_curr_addr_r + rd_number_bytes) == (rd_wrap_boundary + (rd_burst_len * rd_number_bytes)); // Wrap done condition

    // rd_curr_index_r
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_curr_index_r <= #`DLY {`AXI_LEN_WIDTH{1'b0}};
        end
        else if(rd_buff_set) begin
            rd_curr_index_r <= #`DLY rd_dec_miss ? rd_burst_len : `AXI_LEN_WIDTH'h1;   // Set index based on decode miss, quick rlast
        end
        else if(rd_result_en) begin
            rd_curr_index_r <= #`DLY rd_curr_index_r + 1'b1;    // Increment read index
        end
    end

    // rd_wrap_done_r
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_wrap_done_r <= #`DLY 1'b0;
        end
        else if(rd_buff_set) begin
            rd_wrap_done_r <= #`DLY 1'b0; // Clear on buffer set
        end
        else if(rd_data_get) begin
            rd_wrap_done_r <= #`DLY rd_wrap_done | rd_wrap_done_r; // Capture wrap done
        end
    end

    // rd_curr_addr_r
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_curr_addr_r <= #`DLY {`AXI_ADDR_WIDTH{1'b0}};
        end
        else if(rd_buff_set) begin
            rd_curr_addr_r <= #`DLY rd_start_addr; // Set start address on buffer set
        end
        else if(rd_data_get) begin
            case (rd_burst_buff_r)
                `AXI_BURST_FIXED: begin
                    rd_curr_addr_r <= #`DLY rd_curr_addr_r; // Fixed address
                end
                `AXI_BURST_INCR: begin
                    rd_curr_addr_r <= #`DLY rd_curr_addr_r + rd_number_bytes; // Increment address
                end
                `AXI_BURST_WRAP: begin
                    if(rd_wrap_done) begin
                        rd_curr_addr_r <= #`DLY rd_wrap_boundary; // first wrap back to boundary
                    end
                    else if(rd_wrap_done_r) begin
                        rd_curr_addr_r <= #`DLY rd_start_addr + (rd_curr_index_r * rd_number_bytes) - (rd_burst_len * rd_number_bytes); // wrapped address
                    end
                    else begin
                        rd_curr_addr_r <= #`DLY rd_curr_addr_r + rd_number_bytes; // Increment address
                    end
                end
                default: begin
                    rd_curr_addr_r <= #`DLY {`AXI_ADDR_WIDTH{1'b0}};
                end
            endcase
        end
    end

    // ----------------------------------------------------------------
    // read address buffer
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_id_buff_r <= #`DLY {`AXI_ID_WIDTH{1'b0}};
            rd_addr_buff_r <= #`DLY {`AXI_ADDR_WIDTH{1'b0}};
            rd_len_buff_r <= #`DLY {`AXI_LEN_WIDTH{1'b0}};
            rd_size_buff_r <= #`DLY {`AXI_SIZE_WIDTH{1'b0}};
            rd_burst_buff_r <= #`DLY {`AXI_BURST_WIDTH{1'b0}};
        end
        else if(rd_req_en) begin  // On read request handshake
            rd_id_buff_r <= #`DLY axi_slv_arid;
            rd_addr_buff_r <= #`DLY axi_slv_araddr;
            rd_len_buff_r <= #`DLY axi_slv_arlen;
            rd_size_buff_r <= #`DLY axi_slv_arsize;
            rd_burst_buff_r <= #`DLY axi_slv_arburst;
        end
    end

    // ----------------------------------------------------------------
    // read data buffer
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_data_buff_r <= #`DLY {`AXI_DATA_WIDTH{1'b0}};
            rd_resp_buff_r <= #`DLY {`AXI_RESP_WIDTH{1'b0}};
        end
        else if(rd_buff_set) begin
            rd_resp_buff_r <= #`DLY rd_dec_miss ? `AXI_RESP_DECERR : `AXI_RESP_OKAY; // Set response on decode miss
        end
        else if(rd_data_get) begin
            rd_data_buff_r <= #`DLY {{(`AXI_DATA_WIDTH-`AXI_ID_WIDTH-`AXI_ADDR_WIDTH){1'b0}},rd_id_buff_r,rd_curr_addr_r}; // Simulated data: concat ID and address
            rd_resp_buff_r <= #`DLY rd_data_err ? `AXI_RESP_SLVERR : `AXI_RESP_OKAY; // Set response on data error
        end
    end

    // ----------------------------------------------------------------
    // Simulate the data reading process
    // ----------------------------------------------------------------
    // clr_cnt_r logic
    assign rd_data_get = (clr_cnt_r == ({CLR_CNT_WIDTH{1'b1}} - rd_curr_index_r));    // Data fetch condition
    assign rd_data_err = (rd_id_buff_r == `AXI_ID_WIDTH'hF) & (rd_curr_index_r == rd_burst_len);    // Simulated data error when ID is max and last transfer

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            clr_cnt_r <= #`DLY {CLR_CNT_WIDTH{1'b0}};
        end
        else if(rd_req_en & ~rd_dec_miss) begin
            clr_cnt_r <= #`DLY `AXI_LEN_WIDTH'h1;    // Increment counter on valid request
        end
        else if(rd_result_en) begin
            clr_cnt_r <= #`DLY (rd_curr_index_r == rd_burst_len) ? {CLR_CNT_WIDTH{1'b0}} : `AXI_LEN_WIDTH'h1; // Reset or increment counter on result
        end
        else if(rd_data_get) begin
            clr_cnt_r <= #`DLY {CLR_CNT_WIDTH{1'b0}};    // Clear counter on data fetch
        end
        else if(clr_cnt_r != {CLR_CNT_WIDTH{1'b0}}) begin
            clr_cnt_r <= #`DLY clr_cnt_r + 1'b1;    // Increment counter
        end
    end

    // ----------------------------------------------------------------
    // output signals
    // ----------------------------------------------------------------
    // AXI Slave Read Address Channel
    assign axi_slv_arready = (~rd_buff_full);      // Ready when buffer not full
    // AXI Slave Read Data Channel
    assign axi_slv_rdata = rd_data_buff_r;      // Read data output
    assign axi_slv_rresp = rd_resp_buff_r;      // Read response output
    assign axi_slv_rvalid = rd_result_buff_r;   // Read valid signal
    assign axi_slv_rlast = axi_slv_rvalid & (rd_curr_index_r == rd_burst_len);  // Last read flag: when valid and last index

endmodule
