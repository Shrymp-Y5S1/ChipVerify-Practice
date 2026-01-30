module axi_mst(
        input clk,
        input rst_n,

        output [`AXI_ID_WIDTH-1:0] axi_mst_arid,
        output [`AXI_ADDR_WIDTH-1:0] axi_mst_araddr,
        output axi_mst_arvalid,
        input axi_mst_arready
    );
    localparam DLY = 0.1;

    // ----------------------------------------------------------------
    // internal registers
    // ----------------------------------------------------------------

    reg [`AXI_ID_WIDTH-1:0] axi_mst_arid_r;
    reg [`AXI_ADDR_WIDTH-1:0] axi_mst_araddr_r;
    reg axi_mst_arvalid_r;

    // ----------------------------------------------------------------
    // main control
    // ----------------------------------------------------------------

    // handshake logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_mst_arvalid_r <= #DLY 1'b0;
        end
        else if(!axi_mst_arvalid_r) begin
            axi_mst_arvalid_r <= #DLY 1'b1;
        end
        else if(axi_mst_arvalid_r & axi_mst_arready) begin
            axi_mst_arvalid_r <= #DLY 1'b0;
        end
    end

    // address and id logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_mst_arid_r <= #DLY {`AXI_ID_WIDTH{1'b0}};
            axi_mst_araddr_r <= #DLY {`AXI_ADDR_WIDTH{1'b0}};
        end
        else if(axi_mst_arvalid_r & axi_mst_arready) begin
            axi_mst_arid_r <= #DLY axi_mst_arid_r + 1;
            axi_mst_araddr_r <= #DLY (axi_mst_arid_r < 4'hA) ? 16'h0000 : 16'h0001;
        end
    end

    // ----------------------------------------------------------------
    // output signals
    // ----------------------------------------------------------------

    assign axi_mst_arid = axi_mst_arid_r;
    assign axi_mst_araddr = axi_mst_araddr_r;
    assign axi_mst_arvalid = axi_mst_arvalid_r;

endmodule
