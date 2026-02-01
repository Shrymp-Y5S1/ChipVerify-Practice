module axi_mst(
        input clk,
        input rst_n,

        // AXI Master Read Address Channel
        output [`AXI_ID_WIDTH-1:0] axi_mst_arid,
        output [`AXI_ADDR_WIDTH-1:0] axi_mst_araddr,
        output [`AXI_LEN_WIDTH-1:0] axi_mst_arlen,
        output [`AXI_SIZE_WIDTH -1:0] axi_mst_arsize,
        output [`AXI_BURST_WIDTH-1:0] axi_mst_arburst,
        output axi_mst_arvalid,
        input axi_mst_arready,

        // AXI Master Read Data Channel
        input [`AXI_DATA_WIDTH-1:0] axi_mst_rdata,
        input [`AXI_RESP_WIDTH-1:0] axi_mst_rresp,
        input axi_mst_rlast,
        input axi_mst_rvalid,
        output axi_mst_rready
    );

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------
    wire rd_buff_set;      // Buffer set condition
    wire rd_buff_clr;      // Buffer clear condition
    wire rd_buff_full;     // Buffer full flag

    // FSM registers
    reg rd_valid_buff_r;   // Valid buffer register
    reg rd_req_buff_r;     // Request buffer register
    reg rd_comp_buff_r;    // Completion buffer register

    // Read Address buffers
    reg [`AXI_ID_WIDTH-1:0] rd_id_buff_r;           // AXI ID buffer
    reg [`AXI_ADDR_WIDTH-1:0] rd_addr_buff_r;       // AXI Address buffer
    reg [`AXI_LEN_WIDTH-1:0] rd_len_buff_r;         // AXI Length buffer
    reg [`AXI_SIZE_WIDTH-1:0] rd_size_buff_r;       // AXI Size buffer
    reg [`AXI_BURST_WIDTH-1:0] rd_burst_buff_r;     // AXI Burst type buffer

    // Read Data buffers
    reg [`AXI_DATA_WIDTH-1:0] rd_data_buff_r [`AXI_LEN_WIDTH-1:0];       // Read data buffer
    reg [`BURST_CNT_WIDTH-1:0] rd_data_cnt_r;       // Counter for burst data
    reg [`AXI_RESP_WIDTH-1:0] rd_resp_buff_r;       // Read response buffer

    wire rd_req_en;        // Read request handshake(valid & ready)
    wire rd_result_en;     // Read result handshake(valid & ready)
    wire rd_result_last;   // Last read result flag
    wire rd_result_err;    // Read response error flag

    // ----------------------------------------------------------------
    // main control
    // ----------------------------------------------------------------
    assign rd_buff_full = &rd_valid_buff_r;                 // Buffer full if valid buffer all set
    assign rd_buff_set = ~rd_buff_full;                     // Set buffer if not full
    assign rd_buff_clr = rd_valid_buff_r & ~rd_req_buff_r & ~rd_comp_buff_r; // Clear buffer if valid and no pending operations
    assign rd_req_en = axi_mst_arvalid & axi_mst_arready;   // Read address request handshake
    assign rd_result_en = axi_mst_rvalid & axi_mst_rready;  // Read data result handshake
    assign rd_result_last = axi_mst_rlast;                  // Last read result

    // FSM: Valid Buffer Register
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_valid_buff_r <= #`DLY 1'b0;
        end
        else if(rd_buff_set) begin
            rd_valid_buff_r <= #`DLY 1'b1; // Set valid buffer
        end
        else if(rd_buff_clr) begin
            rd_valid_buff_r <= #`DLY 1'b0; // Clear valid buffer
        end
    end

    // FSM: Request Buffer Register
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_req_buff_r <= #`DLY 1'b0;
        end
        else if(rd_buff_set) begin
            rd_req_buff_r <= #`DLY 1'b1; // Set request buffer
        end
        else if(rd_req_en) begin
            rd_req_buff_r <= #`DLY 1'b0; // Clear request buffer on handshake
        end
    end

    // FSM: Completion Buffer Register
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_comp_buff_r <= #`DLY 1'b0;
        end
        else if(rd_buff_set) begin
            rd_comp_buff_r <= #`DLY 1'b1;    // Set completion buffer
        end
        else if(rd_result_en & rd_result_last) begin
            rd_comp_buff_r <= #`DLY 1'b0;    // Clear completion buffer on last read data result handshake
        end
    end

    // Read Data Counter
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_data_cnt_r <= #`DLY {`BURST_CNT_WIDTH{1'b0}};
        end
        else if(rd_buff_set) begin
            rd_data_cnt_r <= #`DLY {`BURST_CNT_WIDTH{1'b0}};
        end
        else if(rd_result_en) begin
            rd_data_cnt_r <= #`DLY rd_data_cnt_r + 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // AXI AR Payload Buffer
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_id_buff_r <= #`DLY {`AXI_ID_WIDTH{1'b0}};
            rd_addr_buff_r <= #`DLY {`AXI_ADDR_WIDTH{1'b0}};
            rd_len_buff_r <= #`DLY {`AXI_LEN_WIDTH{1'b0}};
            rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
            rd_burst_buff_r <= #`DLY `AXI_BURST_INCR;
        end
        else if(rd_req_en) begin    // On read request handshake
            rd_id_buff_r <= #`DLY rd_id_buff_r + `AXI_ID_WIDTH'h1;   // Increment ID for each request
            case (rd_id_buff_r[2:0])
                3'b000: begin
                    rd_addr_buff_r <= #`DLY `AXI_ADDR_WIDTH'h0;
                    rd_burst_buff_r <= #`DLY `AXI_BURST_INCR;
                    rd_len_buff_r <= #`DLY `AXI_LEN_WIDTH'h0;
                    rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
                end
                3'b001: begin
                    rd_addr_buff_r <= #`DLY `AXI_ADDR_WIDTH'h10;
                    rd_burst_buff_r <= #`DLY `AXI_BURST_INCR;
                    rd_len_buff_r <= #`DLY `AXI_LEN_WIDTH'h3;
                    rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
                end
                3'b010: begin
                    rd_addr_buff_r <= #`DLY `AXI_ADDR_WIDTH'h20;
                    rd_burst_buff_r <= #`DLY `AXI_BURST_INCR;
                    rd_len_buff_r <= #`DLY `AXI_LEN_WIDTH'h7;
                    rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
                end
                3'b011: begin
                    rd_addr_buff_r <= #`DLY `AXI_ADDR_WIDTH'h30;
                    rd_burst_buff_r <= #`DLY `AXI_BURST_FIXED;
                    rd_len_buff_r <= #`DLY `AXI_LEN_WIDTH'h3;
                    rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
                end
                3'b100: begin
                    rd_addr_buff_r <= #`DLY `AXI_ADDR_WIDTH'h34;
                    rd_burst_buff_r <= #`DLY `AXI_BURST_WRAP;
                    rd_len_buff_r <= #`DLY `AXI_LEN_WIDTH'h3;
                    rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
                end
                3'b101: begin
                    rd_addr_buff_r <= #`DLY `AXI_ADDR_WIDTH'h38;
                    rd_burst_buff_r <= #`DLY `AXI_BURST_WRAP;
                    rd_len_buff_r <= #`DLY `AXI_LEN_WIDTH'h7;
                    rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
                end
                default: begin
                    rd_addr_buff_r <= #`DLY `AXI_ADDR_WIDTH'h40;
                    rd_burst_buff_r <= #`DLY `AXI_BURST_INCR;
                    rd_len_buff_r <= #`DLY `AXI_LEN_WIDTH'h3;
                    rd_size_buff_r <= #`DLY `AXI_SIZE_4_BYTE;
                end
            endcase
        end
    end

    // ----------------------------------------------------------------
    // AXI R Payload Buffer
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_resp_buff_r <= #`DLY {`AXI_RESP_WIDTH{1'b0}};
        end
        else if(rd_result_en) begin  // On read data result handshake
            rd_resp_buff_r <= #`DLY (axi_mst_rresp > rd_resp_buff_r) ? axi_mst_rresp : rd_resp_buff_r;   // merge is the worst resp
        end
    end

    assign rd_result_err = (rd_resp_buff_r == `AXI_RESP_SLVERR) | (rd_resp_buff_r != `AXI_RESP_DECERR); // Check for read response error

    always @(posedge clk or negedge rst_n) begin
        integer i;
        if(!rst_n) begin
            for (i=0; i < `AXI_LEN_WIDTH; i=i+1) begin
                rd_data_buff_r[i] <= #`DLY {`AXI_DATA_WIDTH{1'b0}};
            end
        end
        else if(rd_result_en) begin
            rd_data_buff_r[rd_data_cnt_r] <= # `DLY axi_mst_rdata;
        end
    end
    // ----------------------------------------------------------------
    // output signals
    // ----------------------------------------------------------------
    // AXI Master Read Address Channel
    assign axi_mst_arid = rd_id_buff_r;
    assign axi_mst_araddr = rd_addr_buff_r;
    assign axi_mst_arlen = rd_len_buff_r;
    assign axi_mst_arsize = rd_size_buff_r;
    assign axi_mst_arburst = rd_burst_buff_r;
    assign axi_mst_arvalid = rd_req_buff_r;
    // AXI Master Read Data Channel
    assign axi_mst_rready = 1'b1;

endmodule
