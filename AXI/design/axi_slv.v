module axi_slv(
        input clk,
        input rst_n,

        input [`AXI_ID_WIDTH-1:0] axi_slv_arid,
        input [`AXI_ADDR_WIDTH-1:0] axi_slv_araddr,
        input axi_slv_arvalid,
        output axi_slv_arready
    );
    localparam DLY = 0.1;

    localparam CLR_CNT_WIDTH = 4;       // Clear counter width
    localparam REG_ADDR = 16'h0;    // Default register address

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------
    reg valid_buff_r;
    reg [`AXI_ID_WIDTH-1:0] id_buff_r;
    reg [`AXI_ADDR_WIDTH-1:0] addr_buff_r;
    reg [CLR_CNT_WIDTH-1:0] clr_cnt_r;

    wire buff_full;
    wire clr;
    wire dec_miss;

    // ----------------------------------------------------------------
    // main control
    // ----------------------------------------------------------------

    // valid_buff_r logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            valid_buff_r <= #DLY 1'b0;
        end
        else if(clr) begin
            valid_buff_r <= #DLY 1'b0; // clear buffer
        end
        else if(axi_slv_arvalid & axi_slv_arready) begin
            valid_buff_r <= #DLY 1'b1; // latch valid on handshake
        end
    end

    // buff_full logic
    assign buff_full = &valid_buff_r;   // all bits set = full

    // id_buff_r and addr_buff_r logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            id_buff_r <= # DLY {`AXI_ID_WIDTH{1'b0}};
            addr_buff_r <= # DLY {`AXI_ADDR_WIDTH{1'b0}};
        end
        else if(clr) begin
            id_buff_r <= # DLY {`AXI_ID_WIDTH{1'b0}};
            addr_buff_r <= # DLY {`AXI_ADDR_WIDTH{1'b0}};
        end
        else if(axi_slv_arvalid & axi_slv_arready) begin
            id_buff_r <= # DLY axi_slv_arid;
            addr_buff_r <= # DLY axi_slv_araddr;
        end
    end

    assign dec_miss = (axi_slv_araddr != REG_ADDR); // address decode miss

    // clr_cnt_r logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            clr_cnt_r <= #DLY {CLR_CNT_WIDTH{1'b0}};
        end
        else if(clr) begin
            clr_cnt_r <= #DLY {CLR_CNT_WIDTH{1'b0}};
        end
        else if(axi_slv_arvalid & axi_slv_arready) begin
            clr_cnt_r <= #DLY clr_cnt_r + 1;
        end
        else if(clr_cnt_r != {CLR_CNT_WIDTH{1'b0}}) begin
            clr_cnt_r <= #DLY clr_cnt_r + 1;
        end
    end

    assign clr = clr_cnt_r == {CLR_CNT_WIDTH{1'b1}};    // clear when counter max

    // ----------------------------------------------------------------
    // output signals
    // ----------------------------------------------------------------
    assign axi_slv_arready = (~buff_full) & (~dec_miss);

endmodule
