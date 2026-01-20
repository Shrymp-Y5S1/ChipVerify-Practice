// 严格按照 AMBA APB Protocol Specification 编写的 APB 接口模块

module APB_interface #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 16,   // 8/16/32 bits wide
    parameter WAIT_STATES = 0   // 0: no wait states, 1: wait state
)(
    // from APB bus
    input PCLK,
    input PRESETn,
    input [ADDR_WIDTH-1:0] PADDR,
    input PSELx,   // Slave select, assume 1 slave only
    input PENABLE,   // 0: setup, 1: access
    input PWRITE,   // 1: write, 0: read
    input [DATA_WIDTH-1:0] PWDATA,
    // from external device
    input rx,
    // to APB bus
    output reg PREADY,
    output reg [DATA_WIDTH-1:0] PRDATA,   // when read
    output PSLVERR,   // 1: error
    // to external device
    output tx
);

    // output declaration of module baud_generate
    wire baud_en;
    wire baud_en_16x;
    // output declaration of module fifo_tx
    reg [DATA_WIDTH-1:0] tx_din_fifo;
    wire [DATA_WIDTH-1:0] tx_dout_fifo;
    wire full_tx;
    wire empty_tx;
    // output declaration of module uart_tx
    wire tx;
    wire tx_busy;
    // output declaration of module fifo_rx
    wire [DATA_WIDTH-1:0] rx_din_fifo;
    reg [DATA_WIDTH-1:0] rx_dout_fifo;
    wire full_rx;
    wire empty_rx;
    // output declaration of module uart_rx
    wire rx_ready;
    wire rx_busy;
    wire rx_error;

    // output declaration of module reg_map
    wire wr_en;
    wire [DATA_WIDTH-1:0] tx_din_fifo;
    wire rd_en;
    wire tx_start;
    wire [1:0] clk_freq_index;
    wire [1:0] baud_rate_index;
    wire PREADY;
    wire [DATA_WIDTH-1:0] PRDATA;
    wire PSLVERR;

    reg_map #(
        .ADDR_WIDTH 	(4   ),
        .DATA_WIDTH 	(16  ))
    u_reg_map(
        .clk             	(clk              ),
        .rst_n           	(rst_n            ),
        .PADDR           	(PADDR            ),
        .PSELx           	(PSELx            ),
        .PENABLE         	(PENABLE          ),
        .PWRITE          	(PWRITE           ),
        .PWDATA          	(PWDATA           ),
        .full_tx         	(full_tx          ),
        .rx_dout_fifo    	(rx_dout_fifo     ),
        .empty_rx        	(empty_rx         ),
        .tx_busy         	(tx_busy          ),
        .rx_error        	(rx_error         ),
        .rx_ready        	(rx_ready         ),
        .rx_busy         	(rx_busy          ),
        .wr_en           	(wr_en            ),
        .tx_din_fifo     	(tx_din_fifo      ),
        .rd_en           	(rd_en            ),
        .tx_start        	(tx_start         ),
        .clk_freq_index  	(clk_freq_index   ),
        .baud_rate_index 	(baud_rate_index  ),
        .PREADY          	(PREADY           ),
        .PRDATA          	(PRDATA           ),
        .PSLVERR         	(PSLVERR          )
    );

    baud_generate #(
        .CLL_FREQ_INDEX (clk_freq_index),   // 0:50MHz, 1:25MHz, 2:12.5MHz
        .BAUD_RATE_INDEX (baud_rate_index)   // 0:115200, 1:57600, 2:38400, 3:19200, 4:9600
    ) u_baud_generate(
        .clk         	(clk          ),
        .rst_n       	(rst_n        ),
        .baud_en     	(baud_en      ),
        .baud_en_16x 	(baud_en_16x  )
    );

    fifo #(
        .DATA_WIDTH 	(8  ),
        .ADDR_WIDTH 	(4  ))
    tx_fifo(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .wr_en 	(wr_en  ),  // from APB interface
        .rd_en 	(!tx_busy  ),
        .din   	(tx_din_fifo    ),  // from APB interface
        .dout  	(tx_dout_fifo   ),
        .full  	(full_tx   ),
        .empty 	(empty_tx  )
    );

    uart_tx #(
        .DATA_WIDTH 	(8  ))
    u_uart_tx(
        .clk      	(clk       ),
        .rst_n    	(rst_n     ),
        .baud_en  	(baud_en   ),
        .tx_data  	(tx_dout_fifo   ),
        .tx_start 	(tx_start  ),   // from APB interface
        .tx       	(tx        ),
        .tx_busy  	(tx_busy   )
    );

    fifo #(
        .DATA_WIDTH 	(8  ),
        .ADDR_WIDTH 	(4  ))
    rx_fifo(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .wr_en 	(!rx_busy  ),
        .rd_en 	(rd_en  ),  // to APB interface
        .din   	(rx_din_fifo    ),
        .dout  	(rx_dout_fifo   ),  // to APB interface
        .full  	(full_rx   ),
        .empty 	(empty_rx  )
    );

    uart_rx #(
        .DATA_WIDTH 	(8  ))
    u_uart_rx(
        .clk         	(clk          ),
        .rst_n       	(rst_n        ),
        .baud_en_16x 	(baud_en_16x  ),
        .rx          	(rx           ),
        .rx_data     	(rx_din_fifo      ),
        .rx_ready    	(rx_ready     ),
        .rx_busy     	(rx_busy      ),
        .rx_error    	(rx_error     )
    );

endmodule
