module axi_top(
        input clk,
        input rst_n
    );

    // output declaration of module axi_mst
    wire [`AXI_ID_WIDTH-1:0] axi_mst_arid;
    wire [`AXI_ADDR_WIDTH-1:0] axi_mst_araddr;
    wire axi_mst_arvalid;
    wire axi_mst_arready;

    axi_mst u_axi_mst(
                .clk             	(clk              ),
                .rst_n           	(rst_n            ),
                .axi_mst_arid    	(axi_mst_arid     ),
                .axi_mst_araddr  	(axi_mst_araddr   ),
                .axi_mst_arvalid 	(axi_mst_arvalid  ),
                .axi_mst_arready 	(axi_mst_arready  )
            );


    // output declaration of module axi_slv
    wire [`AXI_ID_WIDTH-1:0] axi_slv_arid;
    wire [`AXI_ADDR_WIDTH-1:0] axi_slv_araddr;
    wire axi_slv_arvalid;
    wire axi_slv_arready;

    axi_slv u_axi_slv(
                .clk             	(clk              ),
                .rst_n           	(rst_n            ),
                .axi_slv_arid    	(axi_slv_arid     ),
                .axi_slv_araddr  	(axi_slv_araddr   ),
                .axi_slv_arvalid 	(axi_slv_arvalid  ),
                .axi_slv_arready 	(axi_slv_arready  )
            );

    // link master and slave
    assign axi_slv_arid = axi_mst_arid;
    assign axi_slv_araddr = axi_mst_araddr;
    assign axi_slv_arvalid = axi_mst_arvalid;
    assign axi_mst_arready = axi_slv_arready;

endmodule
