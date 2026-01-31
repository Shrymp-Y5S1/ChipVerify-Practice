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
    localparam DLY = 0.1;

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
    reg [`AXI_LEN_WIDTH-1:0]rd_result_index_r; // Current read index

    // Read Address buffers
    reg [`AXI_ID_WIDTH-1:0] rd_id_buff_r;           // AXI ID buffer
    reg [`AXI_ADDR_WIDTH-1:0] rd_addr_buff_r;       // AXI Address buffer
    reg [`AXI_LEN_WIDTH-1:0] rd_len_buff_r;         // AXI Length buffer
    reg [`AXI_SIZE_WIDTH-1:0] rd_size_buff_r;       // AXI Size buffer
    reg [`AXI_BURST_WIDTH-1:0] rd_burst_buff_r;     // AXI Burst type buffer

    // Read Data buffers
    reg [`AXI_DATA_WIDTH-1:0] rd_data_buff_r;       // Read data buffer
    reg [`AXI_RESP_WIDTH-1:0] rd_resp_buff_r;       // Read response buffer

    wire rd_req_en;        // Read address request handshake(valid & ready)
    wire rd_result_en;     // Read data result handshake(valid & ready)
    wire rd_dec_miss;       // Address decode miss flag
    wire rd_result_last;   // Last read result flag
    wire rd_data_get;      // Data fetch condition (counter max)
    wire rd_data_err;      // Data error flag (simulated)

    reg [CLR_CNT_WIDTH-1:0] clr_cnt_r;    // Clear counter for data fetch simulation

    // ----------------------------------------------------------------
    // main control
    // ----------------------------------------------------------------
    assign rd_buff_full = &rd_valid_buff_r;                 // Buffer full if valid buffer all set
    assign rd_buff_set = rd_req_en;   // Set buffer on read request handshake
    assign rd_buff_clr = rd_result_en & rd_result_last;     // Clear buffer on last read result

    assign rd_req_en = axi_slv_arvalid & axi_slv_arready;   // Read request handshake
    assign rd_dec_miss = (axi_slv_araddr != REG_ADDR);      // Address decode miss
    assign rd_result_en = axi_slv_rvalid & axi_slv_rready;  // Read result handshake
    assign rd_result_last = axi_slv_rlast;                  // Last read result

    // FSM: rd_valid_buff_r
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_valid_buff_r <= #DLY 1'b0;
        end
        else if(rd_buff_set) begin
            rd_valid_buff_r <= #DLY 1'b1;
        end
        else if(rd_buff_clr) begin
            rd_valid_buff_r <= #DLY 1'b0;
        end
    end

    // FSM: rd_result_buff_r
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_result_buff_r <= #DLY 1'b0;
            rd_result_index_r <= #DLY {`AXI_LEN_WIDTH{1'b0}};
        end
        else if(rd_buff_set) begin  //
            rd_result_buff_r <= #DLY rd_dec_miss ? 1'b1 : 1'b0;   // Set result buffer on decode miss, quick rvalid
            rd_result_index_r <= #DLY rd_dec_miss ? axi_slv_arlen : {`AXI_LEN_WIDTH{1'b0}}; // Set index based on decode miss, quick rlast
        end
        else if(rd_result_en) begin
            rd_result_buff_r <= #DLY rd_data_get;    // Set result buffer on data fetch condition, clear otherwise
            rd_result_index_r <= #DLY rd_result_index_r + `AXI_LEN_WIDTH'h1;    // Increment read index
        end
        else if(rd_data_get) begin
            rd_result_buff_r <= #DLY 1'b1;    // Set result buffer on data fetch condition
        end
    end

    // ----------------------------------------------------------------
    // read address buffer
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_id_buff_r <= #DLY {`AXI_ID_WIDTH{1'b0}};
            rd_addr_buff_r <= #DLY {`AXI_ADDR_WIDTH{1'b0}};
            rd_len_buff_r <= #DLY {`AXI_LEN_WIDTH{1'b0}};
            rd_size_buff_r <= #DLY {`AXI_SIZE_WIDTH{1'b0}};
            rd_burst_buff_r <= #DLY {`AXI_BURST_WIDTH{1'b0}};
        end
        else if(rd_req_en) begin  // On read request handshake
            rd_id_buff_r <= #DLY axi_slv_arid;
            rd_addr_buff_r <= #DLY axi_slv_araddr;
            rd_len_buff_r <= #DLY axi_slv_arlen;
            rd_size_buff_r <= #DLY axi_slv_arsize;
            rd_burst_buff_r <= #DLY axi_slv_arburst;
        end
    end

    // ----------------------------------------------------------------
    // read data buffer
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_data_buff_r <= #DLY {`AXI_DATA_WIDTH{1'b0}};
            rd_resp_buff_r <= #DLY {`AXI_RESP_WIDTH{1'b0}};
        end
        else if(rd_buff_set) begin
            rd_resp_buff_r <= #DLY rd_dec_miss ? `AXI_RESP_DECERR : `AXI_RESP_OKAY; // Set response on decode miss
        end
        else if(rd_data_get) begin
            rd_data_buff_r <= #DLY rd_data_buff_r + `AXI_DATA_WIDTH'h1; // Simulated data increment
            rd_resp_buff_r <= #DLY rd_data_err ? `AXI_RESP_SLVERR : `AXI_RESP_OKAY; // Set response on data error
        end
    end

    // ----------------------------------------------------------------
    // Simulate the data reading process
    // ----------------------------------------------------------------
    // clr_cnt_r logic
    assign rd_data_get = (clr_cnt_r == ({CLR_CNT_WIDTH{1'b1}} - rd_result_index_r));    // Data fetch condition
    assign rd_data_err = (rd_id_buff_r == `AXI_ID_WIDTH'h9);    // Simulated data error when ID is 9

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            clr_cnt_r <= #DLY {CLR_CNT_WIDTH{1'b0}};
        end
        else if(rd_req_en & ~rd_dec_miss) begin
            clr_cnt_r <= #DLY `AXI_LEN_WIDTH'h1;    // Increment counter on valid request
        end
        else if(rd_result_en) begin
            clr_cnt_r <= #DLY (rd_result_index_r == rd_len_buff_r) ? {CLR_CNT_WIDTH{1'b0}} : `AXI_LEN_WIDTH'h1; // Reset or increment counter on result
        end
        else if(rd_data_get) begin
            clr_cnt_r <= #DLY {CLR_CNT_WIDTH{1'b0}};    // Clear counter on data fetch
        end
        else if(clr_cnt_r != {CLR_CNT_WIDTH{1'b0}}) begin
            clr_cnt_r <= #DLY clr_cnt_r + 1'b1;    // Increment counter
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
    assign axi_slv_rlast = (rd_len_buff_r == rd_result_index_r);  // Last read flag
    assign axi_slv_rvalid = rd_result_buff_r;   // Read valid signal

endmodule
