module axi_top(
        input clk,
        input rst_n,
        output req_finish
    );

    // output declaration of module axi_mst
    wire [`AXI_ID_WIDTH-1:0] axi_mst_arid;
    wire [`AXI_ADDR_WIDTH-1:0] axi_mst_araddr;
    wire [`AXI_LEN_WIDTH-1:0] axi_mst_arlen;
    wire [`AXI_SIZE_WIDTH-1:0] axi_mst_arsize;
    wire [`AXI_BURST_WIDTH-1:0] axi_mst_arburst;
    wire axi_mst_arvalid;
    wire [`AXI_USER_WIDTH-1:0] axi_mst_aruser;
    wire axi_mst_arready;
    wire [`AXI_ID_WIDTH-1:0] axi_mst_rid;
    wire [`AXI_DATA_WIDTH-1:0] axi_mst_rdata;
    wire [`AXI_RESP_WIDTH-1:0] axi_mst_rresp;
    wire axi_mst_rlast;
    wire axi_mst_rvalid;
    wire [`AXI_USER_WIDTH-1:0] axi_mst_ruser;
    wire axi_mst_rready;

    axi_mst u_axi_mst(
                .clk             	(clk              ),
                .rst_n           	(rst_n            ),
                .req_finish         (req_finish       ),
                .axi_mst_arid    	(axi_mst_arid     ),
                .axi_mst_araddr  	(axi_mst_araddr   ),
                .axi_mst_arlen   	(axi_mst_arlen    ),
                .axi_mst_arsize  	(axi_mst_arsize   ),
                .axi_mst_arburst 	(axi_mst_arburst  ),
                .axi_mst_arvalid 	(axi_mst_arvalid  ),
                .axi_mst_aruser     (axi_mst_aruser   ),
                .axi_mst_arready 	(axi_mst_arready  ),
                .axi_mst_rid   	    (axi_mst_rid      ),
                .axi_mst_rdata   	(axi_mst_rdata    ),
                .axi_mst_rresp   	(axi_mst_rresp    ),
                .axi_mst_rlast   	(axi_mst_rlast    ),
                .axi_mst_rvalid  	(axi_mst_rvalid   ),
                .axi_mst_ruser      (axi_mst_ruser    ),
                .axi_mst_rready  	(axi_mst_rready   )
            );


    // output declaration of module axi_slv
    wire [`AXI_ID_WIDTH-1:0] axi_slv_arid;
    wire [`AXI_ADDR_WIDTH-1:0] axi_slv_araddr;
    wire [`AXI_LEN_WIDTH-1:0] axi_slv_arlen;
    wire [`AXI_SIZE_WIDTH-1:0] axi_slv_arsize;
    wire [`AXI_BURST_WIDTH-1:0] axi_slv_arburst;
    wire axi_slv_arvalid;
    wire axi_slv_arready;
    wire [`AXI_USER_WIDTH-1:0] axi_slv_aruser;
    wire [`AXI_ID_WIDTH-1:0] axi_slv_rid;
    wire [`AXI_DATA_WIDTH-1:0] axi_slv_rdata;
    wire [`AXI_RESP_WIDTH-1:0] axi_slv_rresp;
    wire axi_slv_rlast;
    wire axi_slv_rvalid;
    wire [`AXI_USER_WIDTH-1:0] axi_slv_ruser;
    wire axi_slv_rready;

    axi_slv u_axi_slv(
                .clk             	(clk              ),
                .rst_n           	(rst_n            ),
                .axi_slv_arid    	(axi_slv_arid     ),
                .axi_slv_araddr  	(axi_slv_araddr   ),
                .axi_slv_arlen   	(axi_slv_arlen    ),
                .axi_slv_arsize  	(axi_slv_arsize   ),
                .axi_slv_arburst 	(axi_slv_arburst  ),
                .axi_slv_arvalid 	(axi_slv_arvalid  ),
                .axi_slv_aruser     (axi_slv_aruser   ),
                .axi_slv_arready 	(axi_slv_arready  ),
                .axi_slv_rid        (axi_slv_rid      ),
                .axi_slv_rdata   	(axi_slv_rdata    ),
                .axi_slv_rresp   	(axi_slv_rresp    ),
                .axi_slv_rlast   	(axi_slv_rlast    ),
                .axi_slv_rvalid  	(axi_slv_rvalid   ),
                .axi_slv_ruser      (axi_slv_ruser    ),
                .axi_slv_rready  	(axi_slv_rready   )
            );


    // link master and slave
    assign axi_slv_arid    = axi_mst_arid;
    assign axi_slv_araddr  = axi_mst_araddr;
    assign axi_slv_arlen   = axi_mst_arlen;
    assign axi_slv_arsize  = axi_mst_arsize;
    assign axi_slv_arburst = axi_mst_arburst;
    assign axi_slv_arvalid = axi_mst_arvalid;
    assign axi_mst_arready = axi_slv_arready;
    assign axi_slv_aruser  = axi_mst_aruser;
    assign axi_mst_rid     = axi_slv_rid;
    assign axi_mst_rdata   = axi_slv_rdata;
    assign axi_mst_rresp   = axi_slv_rresp;
    assign axi_mst_rlast   = axi_slv_rlast;
    assign axi_mst_rvalid  = axi_slv_rvalid;
    assign axi_slv_rready  = axi_mst_rready;
    assign axi_mst_ruser   = axi_slv_ruser;

endmodule
