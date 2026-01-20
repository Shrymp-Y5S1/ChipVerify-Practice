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
    output PREADY,
    output reg [DATA_WIDTH-1:0] PRDATA,
    output PSLVERR,   // 1: error
    // to external device
    output tx
);

    // output declaration of module baud_generate
    wire baud_en;
    wire baud_en_16x;
    // output declaration of module fifo_tx
    wire [DATA_WIDTH-1:0] tx_din_fifo;
    wire [DATA_WIDTH-1:0] tx_dout_fifo;
    wire full_tx;
    wire empty_tx;
    // output declaration of module uart_tx
    wire tx;
    wire tx_busy;
    // output declaration of module fifo_rx
    wire [DATA_WIDTH-1:0] rx_din_fifo;
    wire [DATA_WIDTH-1:0] rx_dout_fifo;
    wire full_rx;
    wire empty_rx;
    // output declaration of module uart_rx
    wire rx_ready;
    wire rx_busy;
    wire rx_error;
    // output declaration of module reg_map
    wire wr_en;
    wire rd_en;
    wire tx_start;
    wire [1:0] clk_freq_index;
    wire [1:0] baud_rate_index;
    wire [DATA_WIDTH-1:0] PRDATA;
    wire PSLVERR;
    // clock frequency and baud rate
    reg [31:0] clock_frequency;
    reg [31:0] baud_rate;

    reg_map #(
        .ADDR_WIDTH 	(4   ),
        .DATA_WIDTH 	(16  ))
    u_reg_map(
        .clk             	(PCLK             ),
        .rst_n           	(PRESETn          ),
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

    // Clock frequency
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)
            clock_frequency <= 50_000_000;
        else begin
            case(clk_freq_index)
                2'b00:clock_frequency <= 50_000_000; // 50 MHz
                2'b01:clock_frequency <= 25_000_000; // 25 MHz
                2'b10:clock_frequency <= 12_500_000; // 12.5 MHz
                default:clock_frequency <= 50_000_000;
            endcase
        end
    end

    // Baud rate
    always @(posedge PCLK or negedge PRESETn)begin
        if(!PRESETn)
            baud_rate <= 115_200;
        else begin
            case(baud_rate_index)
                3'b000:baud_rate <= 115_200;
                3'b001:baud_rate <= 57_600;
                3'b010:baud_rate <= 38_400;
                3'b011:baud_rate <= 19_200;
                3'b100:baud_rate <= 9_600;
                default:baud_rate <= 115_200;
            endcase
	    end
    end

    baud_generate #(
        .CLL_FREQ_INDEX (clock_frequency),
        .BAUD_RATE_INDEX (baud_rate)
    ) u_baud_generate(
        .clk         	(PCLK         ),
        .rst_n       	(PRESETn      ),
        .baud_en     	(baud_en      ),
        .baud_en_16x 	(baud_en_16x  )
    );

    fifo #(
        .DATA_WIDTH 	(8  ),
        .ADDR_WIDTH 	(4  ))
    tx_fifo(
        .clk   	(PCLK           ),
        .rst_n 	(PRESETn        ),
        .wr_en 	(wr_en          ),  // from APB interface
        .rd_en 	(!tx_busy       ),
        .din   	(tx_din_fifo    ),  // from APB interface
        .dout  	(tx_dout_fifo   ),
        .full  	(full_tx        ),
        .empty 	(empty_tx       )
    );

    uart_tx #(
        .DATA_WIDTH 	(8  ))
    u_uart_tx(
        .clk      	(PCLK           ),
        .rst_n    	(PRESETn        ),
        .baud_en  	(baud_en        ),
        .tx_data  	(tx_dout_fifo   ),
        .tx_start 	(tx_start       ),   // from APB interface
        .tx       	(tx             ),
        .tx_busy  	(tx_busy        )
    );

    fifo #(
        .DATA_WIDTH 	(8  ),
        .ADDR_WIDTH 	(4  ))
    rx_fifo(
        .clk   	(PCLK           ),
        .rst_n 	(PRESETn        ),
        .wr_en 	(!rx_busy       ),
        .rd_en 	(rd_en          ),  // to APB interface
        .din   	(rx_din_fifo    ),
        .dout  	(rx_dout_fifo   ),  // to APB interface
        .full  	(full_rx        ),
        .empty 	(empty_rx       )
    );

    uart_rx #(
        .DATA_WIDTH 	(8  ))
    u_uart_rx(
        .clk         	(PCLK         ),
        .rst_n       	(PRESETn      ),
        .baud_en_16x 	(baud_en_16x  ),
        .rx          	(rx           ),
        .rx_data     	(rx_din_fifo  ),
        .rx_ready    	(rx_ready     ),
        .rx_busy     	(rx_busy      ),
        .rx_error    	(rx_error     )
    );

endmodule
