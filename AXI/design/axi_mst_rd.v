module axi_mst_rd #(
        parameter OST_DEPTH = 16     // Outstanding transaction depth
    )(
        input clk,
        input rst_n,
        // VCS coverage off
        input rd_en,
        // VCS coverage on

        // User Request Interface
        input user_req_valid,
        output user_req_ready,
        input [`AXI_ID_WIDTH-1:0] user_req_id,
        input [`AXI_ADDR_WIDTH-1:0] user_req_addr,
        input [`AXI_LEN_WIDTH-1:0] user_req_len,
        input [`AXI_SIZE_WIDTH-1:0] user_req_size,
        input [`AXI_BURST_WIDTH-1:0] user_req_burst,

        // AXI Master Read Address Channel
        output [`AXI_ID_WIDTH-1:0] axi_mst_arid,
        output [`AXI_ADDR_WIDTH-1:0] axi_mst_araddr,
        output [`AXI_LEN_WIDTH-1:0] axi_mst_arlen,
        output [`AXI_SIZE_WIDTH -1:0] axi_mst_arsize,
        output [`AXI_BURST_WIDTH-1:0] axi_mst_arburst,
        // VCS coverage off
        output [`AXI_USER_WIDTH-1:0] axi_mst_aruser,
        // VCS coverage on
        output axi_mst_arvalid,
        input axi_mst_arready,

        // AXI Master Read Data Channel
        input [`AXI_ID_WIDTH-1:0] axi_mst_rid,
        input [`AXI_DATA_WIDTH-1:0] axi_mst_rdata,
        input [`AXI_RESP_WIDTH-1:0] axi_mst_rresp,
        // VCS coverage off
        input [`AXI_USER_WIDTH-1:0] axi_mst_ruser,
        // VCS coverage on
        input axi_mst_rlast,
        input axi_mst_rvalid,
        output axi_mst_rready
    );
    localparam MAX_BURST_LEN = 8;                           // Maximum burst length
    localparam BURST_CNT_WIDTH = $clog2(MAX_BURST_LEN+1);   // Width of burst counter
    localparam OST_CNT_WIDTH = $clog2(OST_DEPTH + 1);       // Width of outstanding transaction counter
    localparam MAX_REQ_NUM = 16;                            // Maximum number of requests
    localparam REQ_CNT_WIDTH = $clog2(MAX_REQ_NUM + 1);     // Width of request counter

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------
    wire rd_buff_set;      // Buffer set condition
    wire rd_buff_clr;      // Buffer clear condition
    wire rd_buff_full;     // Buffer full flag

    // FSM registers
    reg rd_valid_buff_r [OST_DEPTH-1:0];   // Valid buffer register
    reg rd_req_buff_r [OST_DEPTH-1:0];     // Request buffer register
    reg rd_comp_buff_r [OST_DEPTH-1:0];    // Completion buffer register
    reg rd_clear_buff_r [OST_DEPTH-1:0];  // Clear buffer register

    // arrays -> registers
    reg [OST_DEPTH-1:0] rd_valid_bits;
    wire [OST_DEPTH-1:0] rd_set_bits;
    reg [OST_DEPTH-1:0] rd_req_bits;
    reg [OST_DEPTH-1:0] rd_clear_bits;

    // Read pointers
    wire [OST_CNT_WIDTH-1:0] rd_ptr_set_r;
    wire [OST_CNT_WIDTH-1:0] rd_ptr_clr_r;
    wire [OST_CNT_WIDTH-1:0] rd_ptr_req_r;
    wire [OST_CNT_WIDTH-1:0] rd_ptr_result_r;

    // Read Address buffers
    reg [`AXI_ID_WIDTH-1:0] rd_id_buff_r [OST_DEPTH-1:0];           // AXI ID buffer
    reg [`AXI_ADDR_WIDTH-1:0] rd_addr_buff_r [OST_DEPTH-1:0];       // AXI Address buffer
    reg [`AXI_LEN_WIDTH-1:0] rd_len_buff_r [OST_DEPTH-1:0];         // AXI Length buffer
    reg [`AXI_SIZE_WIDTH-1:0] rd_size_buff_r [OST_DEPTH-1:0];       // AXI Size buffer
    reg [`AXI_BURST_WIDTH-1:0] rd_burst_buff_r [OST_DEPTH-1:0];     // AXI Burst type buffer

    // Read Data buffers
    reg [`AXI_DATA_WIDTH*MAX_BURST_LEN-1:0] rd_data_buff_r [OST_DEPTH-1:0];     // Read data buffer
    reg [BURST_CNT_WIDTH-1:0] rd_data_cnt_r [OST_DEPTH-1:0];                    // Counter for burst data
    reg [`AXI_RESP_WIDTH-1:0] rd_resp_buff_r [OST_DEPTH-1:0];                   // Read response buffer
    wire [OST_DEPTH-1:0] rd_resp_err;                                           // Read response error flag

    wire rd_req_en;                         // Read request handshake(valid & ready)
    wire rd_result_en;                      // Read result handshake(valid & ready)
    wire rd_result_last;                    // Last read result flag

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
              u_rd_req_arbit(
                  .clk       	(clk        ),
                  .rst_n     	(rst_n      ),
                  .queue_i   	(rd_req_bits    ),
                  .sche_en   	(rd_req_en    ),
                  .pointer_o 	(rd_ptr_req_r  )
              );

    // ----------------------------------------------------------------
    // Main Control
    // ----------------------------------------------------------------
    // array -> register conversion
    always @(*) begin: MST_RD_CLEAR_VEC
        integer i;
        rd_clear_bits = {OST_DEPTH{1'b0}};
        for(i=0; i<OST_DEPTH; i=i+1) begin
            rd_clear_bits[i] = rd_clear_buff_r[i];
        end
    end

    always @(*) begin: MST_RD_REQ_VEC
        integer i;
        rd_req_bits = {OST_DEPTH{1'b0}};
        for(i=0; i<OST_DEPTH; i=i+1) begin
            rd_req_bits[i] = rd_req_buff_r[i];
        end
    end

    always @(*) begin: MST_RD_VALID_VEC
        integer i;
        rd_valid_bits = {OST_DEPTH{1'b0}};
        for (i=0;i < OST_DEPTH; i=i+1) begin
            rd_valid_bits[i] = rd_valid_buff_r[i];
        end
    end
    assign rd_buff_full = &rd_valid_bits;                   // Buffer full if valid bits all set
    assign rd_buff_set = ~rd_buff_full & user_req_valid & rd_en;                     // Set buffer if not full
    assign rd_set_bits = ~rd_valid_bits;   // Set bits are where valid bits are 0

    assign rd_buff_clr = rd_valid_buff_r[rd_ptr_clr_r] & ~rd_req_buff_r[rd_ptr_clr_r] & ~rd_comp_buff_r[rd_ptr_clr_r];      // Clear buffer if valid and no pending operations
    assign rd_req_en = axi_mst_arvalid & axi_mst_arready;   // Read address request handshake
    assign rd_result_en = axi_mst_rvalid & axi_mst_rready;  // Read data result handshake
    assign rd_result_last = axi_mst_rlast;                  // Last read result

    genvar i;
    generate
        for (i=0; i<OST_DEPTH; i=i+1) begin: OST_BUFFER_FSM
            // FSM: Valid Buffer Register
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

            // FSM: Request Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_req_buff_r[i] <= #`DLY 1'b0;
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_req_buff_r[i] <= #`DLY 1'b1;
                end
                else if(rd_req_en && (i == rd_ptr_req_r)) begin
                    rd_req_buff_r[i] <= #`DLY 1'b0;
                end
            end

            // FSM: Completion Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_comp_buff_r[i] <= #`DLY 1'b0;
                end
                else if(rd_buff_set && (i == rd_ptr_set_r)) begin
                    rd_comp_buff_r[i] <= #`DLY 1'b1;
                end
                else if(rd_result_en & rd_result_last && (rd_ptr_result_r == i)) begin
                    rd_comp_buff_r[i] <= #`DLY 1'b0;    // Clear completion buffer on last read data result handshake
                end
            end

            // FSM: Clear Buffer Register
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_clear_buff_r[i] <= #`DLY 1'b0;
                end
                else begin
                    rd_clear_buff_r[i] <= #`DLY rd_valid_buff_r[i] & ~rd_req_buff_r[i] & ~rd_comp_buff_r[i];
                end
            end

            // ----------------------------------------------------------------
            // AXI AR Payload Buffer
            // ----------------------------------------------------------------
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_id_buff_r[i] <= #`DLY `AXI_ID_WIDTH'h0;
                    rd_addr_buff_r[i] <= #`DLY `AXI_ADDR_WIDTH'h0;
                    rd_len_buff_r[i] <= #`DLY `AXI_LEN_WIDTH'h0;
                    rd_size_buff_r[i] <= #`DLY `AXI_SIZE_1_BYTE;
                    rd_burst_buff_r[i] <= #`DLY `AXI_BURST_INCR;
                end
                else if(rd_buff_set && (rd_ptr_set_r == i)) begin
                    rd_id_buff_r[i] <= #`DLY user_req_id;
                    rd_addr_buff_r[i] <= #`DLY user_req_addr;
                    rd_len_buff_r[i] <= #`DLY user_req_len;
                    rd_size_buff_r[i] <= #`DLY user_req_size;
                    rd_burst_buff_r[i] <= #`DLY user_req_burst;
                end
            end

            // ----------------------------------------------------------------
            // AXI R Payload Buffer
            // ----------------------------------------------------------------
            // Read Response Buffer
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_resp_buff_r[i] <= #`DLY {`AXI_RESP_WIDTH{1'b0}};
                end
                else if(rd_result_en && (rd_ptr_result_r == i)) begin  // On read data result handshake
                    rd_resp_buff_r[i] <= #`DLY (axi_mst_rresp > rd_resp_buff_r[i]) ? axi_mst_rresp : rd_resp_buff_r[i];   // merge is the worst resp
                end
            end
            // Read Response Error Flag
            assign rd_resp_err[i] = (rd_resp_buff_r[i] == `AXI_RESP_SLVERR) | (rd_resp_buff_r[i] == `AXI_RESP_DECERR); // Check for read response error

            // Read Data Counter
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(rd_buff_set && (rd_ptr_set_r == i)) begin
                    rd_data_cnt_r[i] <= #`DLY {BURST_CNT_WIDTH{1'b0}};
                end
                else if(rd_result_en && (rd_ptr_result_r == i)) begin
                    rd_data_cnt_r[i] <= #`DLY rd_data_cnt_r[i] + 1'b1;
                end
            end
            // Read Data Buffer
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    rd_data_buff_r[i] <= #`DLY {`AXI_DATA_WIDTH*MAX_BURST_LEN{1'b0}};
                end
                else if(rd_buff_set && (rd_ptr_set_r == i)) begin
                    rd_data_buff_r[i] <= #`DLY {`AXI_DATA_WIDTH*MAX_BURST_LEN{1'b0}};
                end
                else if(rd_result_en && (rd_ptr_result_r == i)) begin
                    rd_data_buff_r[i][rd_data_cnt_r[i]*`AXI_DATA_WIDTH +: `AXI_DATA_WIDTH] <= # `DLY axi_mst_rdata;
                end
            end
        end
    endgenerate

    // ----------------------------------------------------------------
    // RESP ID ORDER CONTROL
    // ----------------------------------------------------------------
    axi_order #(
                  .OST_DEPTH 	(OST_DEPTH  ),
                  .ID_WIDTH  	(`AXI_ID_WIDTH))
              u_axi_idorder(
                  .clk        	(clk         ),
                  .rst_n      	(rst_n       ),
                  .push  	    (axi_mst_arvalid & axi_mst_arready   ),
                  .push_id     	(axi_mst_arid      ),
                  .push_ptr    	(rd_ptr_req_r     ),
                  .pop  	    (axi_mst_rvalid & axi_mst_rready  ),
                  .pop_id    	(axi_mst_rid     ),
                  .pop_last  	(axi_mst_rlast   ),
                  .order_ptr   	(rd_ptr_result_r    ),
                  .order_bits  	(   )
              );

    // ----------------------------------------------------------------
    // output signals
    // ----------------------------------------------------------------
    // User request ready when buffer not full
    assign user_req_ready = ~rd_buff_full;

    // AXI Master Read Address Channel
    assign axi_mst_arid = rd_id_buff_r [rd_ptr_req_r];
    assign axi_mst_araddr = rd_addr_buff_r [rd_ptr_req_r];
    assign axi_mst_arlen = rd_len_buff_r [rd_ptr_req_r];
    assign axi_mst_arsize = rd_size_buff_r [rd_ptr_req_r];
    assign axi_mst_arburst = rd_burst_buff_r [rd_ptr_req_r];
    assign axi_mst_arvalid = |rd_req_bits;
    // AXI Master Read Data Channel
    assign axi_mst_rready = 1'b1;

endmodule
