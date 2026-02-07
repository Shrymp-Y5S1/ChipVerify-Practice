module axi_top(
        input clk,
        input rst_n,
        input rd_en,
        input wr_en,
        output rd_req_finish,
        output wr_req_finish
    );

    // output declaration of module axi_mst_rd
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

    axi_mst_rd u_axi_mst_rd(
                   .clk             	(clk              ),
                   .rst_n           	(rst_n            ),
                   .rd_en               (rd_en              ),
                   .rd_req_finish       (rd_req_finish       ),
                   .axi_mst_arid    	(axi_mst_arid     ),
                   .axi_mst_araddr  	(axi_mst_araddr   ),
                   .axi_mst_arlen   	(axi_mst_arlen    ),
                   .axi_mst_arsize  	(axi_mst_arsize   ),
                   .axi_mst_arburst 	(axi_mst_arburst  ),
                   .axi_mst_arvalid 	(axi_mst_arvalid  ),
                   .axi_mst_aruser      (axi_mst_aruser   ),
                   .axi_mst_arready 	(axi_mst_arready  ),
                   .axi_mst_rid   	    (axi_mst_rid      ),
                   .axi_mst_rdata   	(axi_mst_rdata    ),
                   .axi_mst_rresp   	(axi_mst_rresp    ),
                   .axi_mst_rlast   	(axi_mst_rlast    ),
                   .axi_mst_rvalid  	(axi_mst_rvalid   ),
                   .axi_mst_ruser       (axi_mst_ruser    ),
                   .axi_mst_rready  	(axi_mst_rready   )
               );


    // output declaration of module axi_slv_rd
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

    axi_slv_rd u_axi_slv_rd(
                   .clk             	(clk              ),
                   .rst_n           	(rst_n            ),
                   .axi_slv_arid    	(axi_slv_arid     ),
                   .axi_slv_araddr  	(axi_slv_araddr   ),
                   .axi_slv_arlen   	(axi_slv_arlen    ),
                   .axi_slv_arsize  	(axi_slv_arsize   ),
                   .axi_slv_arburst 	(axi_slv_arburst  ),
                   .axi_slv_arvalid 	(axi_slv_arvalid  ),
                   .axi_slv_aruser      (axi_slv_aruser   ),
                   .axi_slv_arready 	(axi_slv_arready  ),
                   .axi_slv_rid         (axi_slv_rid      ),
                   .axi_slv_rdata   	(axi_slv_rdata    ),
                   .axi_slv_rresp   	(axi_slv_rresp    ),
                   .axi_slv_rlast   	(axi_slv_rlast    ),
                   .axi_slv_rvalid  	(axi_slv_rvalid   ),
                   .axi_slv_ruser       (axi_slv_ruser    ),
                   .axi_slv_rready  	(axi_slv_rready   )
               );

    // output declaration of module axi_slv_wr
    wire [`AXI_ID_WIDTH-1:0] axi_slv_awid;
    wire [`AXI_ADDR_WIDTH-1:0] axi_slv_awaddr;
    wire [`AXI_LEN_WIDTH-1:0] axi_slv_awlen;
    wire [`AXI_SIZE_WIDTH-1:0] axi_slv_awsize;
    wire [`AXI_BURST_WIDTH-1:0] axi_slv_awburst;
    wire [`AXI_USER_WIDTH-1:0] axi_slv_awuser;
    wire axi_slv_awvalid;
    wire axi_slv_awready;
    wire [`AXI_DATA_WIDTH-1:0] axi_slv_wdata;
    wire [(`AXI_DATA_WIDTH >> 3)-1:0] axi_slv_wstrb;
    wire [`AXI_USER_WIDTH-1:0] axi_slv_wuser;
    wire axi_slv_wlast;
    wire axi_slv_wvalid;
    wire axi_slv_wready;
    wire [`AXI_ID_WIDTH-1:0] axi_slv_bid;
    wire [`AXI_RESP_WIDTH-1:0] axi_slv_bresp;
    wire [`AXI_USER_WIDTH-1:0] axi_slv_buser;
    wire axi_slv_bvalid;
    wire axi_slv_bready;

    axi_slv_wr u_axi_slv_wr(
                   .clk             	(clk              ),
                   .rst_n           	(rst_n            ),
                   .axi_slv_awid    	(axi_slv_awid     ),
                   .axi_slv_awaddr  	(axi_slv_awaddr   ),
                   .axi_slv_awlen   	(axi_slv_awlen    ),
                   .axi_slv_awsize  	(axi_slv_awsize   ),
                   .axi_slv_awburst 	(axi_slv_awburst  ),
                   .axi_slv_awuser  	(axi_slv_awuser   ),
                   .axi_slv_awvalid 	(axi_slv_awvalid  ),
                   .axi_slv_awready 	(axi_slv_awready  ),
                   .axi_slv_wdata   	(axi_slv_wdata    ),
                   .axi_slv_wstrb   	(axi_slv_wstrb    ),
                   .axi_slv_wuser   	(axi_slv_wuser    ),
                   .axi_slv_wlast   	(axi_slv_wlast    ),
                   .axi_slv_wvalid  	(axi_slv_wvalid   ),
                   .axi_slv_wready  	(axi_slv_wready   ),
                   .axi_slv_bid     	(axi_slv_bid      ),
                   .axi_slv_bresp   	(axi_slv_bresp    ),
                   .axi_slv_buser   	(axi_slv_buser    ),
                   .axi_slv_bvalid  	(axi_slv_bvalid   ),
                   .axi_slv_bready  	(axi_slv_bready   )
               );

    // output declaration of module axi_mst_wr
    wire [`AXI_ID_WIDTH-1:0] axi_mst_awid;
    wire [`AXI_ADDR_WIDTH-1:0] axi_mst_awaddr;
    wire [`AXI_LEN_WIDTH-1:0] axi_mst_awlen;
    wire [`AXI_SIZE_WIDTH-1:0] axi_mst_awsize;
    wire [`AXI_BURST_WIDTH-1:0] axi_mst_awburst;
    wire [`AXI_USER_WIDTH-1:0] axi_mst_awuser;
    wire axi_mst_awvalid;
    wire axi_mst_awready;
    wire [`AXI_DATA_WIDTH-1:0] axi_mst_wdata;
    wire [(`AXI_DATA_WIDTH >> 3)-1:0] axi_mst_wstrb;
    wire [`AXI_USER_WIDTH-1:0] axi_mst_wuser;
    wire axi_mst_wlast;
    wire axi_mst_wvalid;
    wire axi_mst_wready;
    wire [`AXI_ID_WIDTH-1:0] axi_mst_bid;
    wire [`AXI_RESP_WIDTH-1:0] axi_mst_bresp;
    wire [`AXI_USER_WIDTH-1:0] axi_mst_buser;
    wire axi_mst_bvalid;
    wire axi_mst_bready;

    axi_mst_wr u_axi_mst_wr(
                   .clk             	(clk              ),
                   .rst_n           	(rst_n            ),
                   .wr_en               (wr_en            ),
                   .wr_req_finish       (wr_req_finish    ),
                   .axi_mst_awid    	(axi_mst_awid     ),
                   .axi_mst_awaddr  	(axi_mst_awaddr   ),
                   .axi_mst_awlen   	(axi_mst_awlen    ),
                   .axi_mst_awsize  	(axi_mst_awsize   ),
                   .axi_mst_awburst 	(axi_mst_awburst  ),
                   .axi_mst_awuser  	(axi_mst_awuser   ),
                   .axi_mst_awvalid 	(axi_mst_awvalid  ),
                   .axi_mst_awready 	(axi_mst_awready  ),
                   .axi_mst_wdata   	(axi_mst_wdata    ),
                   .axi_mst_wstrb   	(axi_mst_wstrb    ),
                   .axi_mst_wuser   	(axi_mst_wuser    ),
                   .axi_mst_wlast   	(axi_mst_wlast    ),
                   .axi_mst_wvalid  	(axi_mst_wvalid   ),
                   .axi_mst_wready  	(axi_mst_wready   ),
                   .axi_mst_bid     	(axi_mst_bid      ),
                   .axi_mst_bresp   	(axi_mst_bresp    ),
                   .axi_mst_buser   	(axi_mst_buser    ),
                   .axi_mst_bvalid  	(axi_mst_bvalid   ),
                   .axi_mst_bready  	(axi_mst_bready   )
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

    assign axi_slv_awid    = axi_mst_awid ;
    assign axi_slv_awaddr  = axi_mst_awaddr;
    assign axi_slv_awlen   = axi_mst_awlen;
    assign axi_slv_awsize  = axi_mst_awsize;
    assign axi_slv_awburst = axi_mst_awburst;
    assign axi_slv_awuser  = axi_mst_awuser;
    assign axi_slv_awvalid = axi_mst_awvalid;
    assign axi_mst_awready = axi_slv_awready;
    assign axi_slv_wdata   = axi_mst_wdata;
    assign axi_slv_wstrb   = axi_mst_wstrb;
    assign axi_slv_wuser   = axi_mst_wuser;
    assign axi_slv_wlast   = axi_mst_wlast;
    assign axi_slv_wvalid  = axi_mst_wvalid;
    assign axi_mst_wready  = axi_slv_wready;

    assign axi_mst_bid     = axi_slv_bid;
    assign axi_mst_bresp   = axi_slv_bresp;
    assign axi_mst_buser   = axi_slv_buser;
    assign axi_mst_bvalid  = axi_slv_bvalid;
    assign axi_slv_bready  = axi_mst_bready;

endmodule
