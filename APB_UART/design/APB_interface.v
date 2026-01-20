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
    output [DATA_WIDTH-1:0] PRDATA,
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
    wire data_ack;
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
    wire rd_en_rx_fifo;
    wire [1:0] clk_freq_index;
    wire [1:0] baud_rate_index;
    // clock frequency and baud rate
    reg [31:0] divisor;

    reg_map #(
        .ADDR_WIDTH 	(4   ),
        .DATA_WIDTH 	(16  ))
    u_reg_map(
        .PCLK             	(PCLK             ),
        .PRESETn           	(PRESETn          ),
        .PADDR           	(PADDR            ),
        .PSELx           	(PSELx            ),
        .PENABLE         	(PENABLE          ),
        .PWRITE          	(PWRITE           ),
        .PWDATA          	(PWDATA           ),
        .full_tx         	(full_tx          ),
        .rx_dout_fifo    	(rx_dout_fifo     ),
        .empty_rx        	(empty_rx         ),
        .tx_busy         	(tx_busy          ),
        .tx_ready 	        (data_ack                ),
        .rx_error        	(rx_error         ),
        .rx_ready        	(rx_ready         ),
        .rx_busy         	(rx_busy          ),
        .wr_en           	(wr_en            ),
        .tx_din_fifo     	(tx_din_fifo      ),
        .rd_en_rx_fifo      (rd_en_rx_fifo    ),
        .clk_freq_index  	(clk_freq_index   ),
        .baud_rate_index 	(baud_rate_index  ),
        .PREADY          	(PREADY           ),
        .PRDATA          	(PRDATA           ),
        .PSLVERR         	(PSLVERR          )
    );

    always @(*)begin
        case(baud_rate_index)   // 0:115200, 1:57600, 2:38400, 3:19200, 4:9600
            3'b000:divisor = 434;
            3'b001:divisor = 868;
            3'b010:divisor = 1302;
            3'b011:divisor = 2604;
            3'b100:divisor = 5208;
            default:divisor = 434;
        endcase
        case(clk_freq_index)    // 0:50MHz, 1:25MHz, 2:12.5MHz
            2'b00:divisor = divisor;
            2'b01:divisor = divisor >>1;
            2'b10:divisor = divisor >>2;
            default:divisor = divisor;
        endcase
    end

    baud_generate  u_baud_generate(
        .clk         	(PCLK         ),
        .rst_n       	(PRESETn      ),
        .divisor        (divisor      ),
        .baud_en     	(baud_en      ),
        .baud_en_16x 	(baud_en_16x  )
    );

    fifo #(
        .DATA_WIDTH 	(8  ),
        .ADDR_WIDTH 	(4  ))
    tx_fifo(
        .clk   	(PCLK           ),
        .rst_n 	(PRESETn        ),
        .wr_en 	(wr_en          ),
        .rd_en 	(data_ack       ),
        .din   	(tx_din_fifo    ),
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
        .tx_start 	(!empty_tx && !tx_busy       ),
        .tx       	(tx             ),
        .tx_busy  	(tx_busy        ),
        .data_ack 	(       data_ack       )
    );

    fifo #(
        .DATA_WIDTH 	(8  ),
        .ADDR_WIDTH 	(4  ))
    rx_fifo(
        .clk   	(PCLK           ),
        .rst_n 	(PRESETn        ),
        .wr_en 	(rx_ready       ),
        .rd_en 	(rd_en_rx_fifo  ),
        .din   	(rx_din_fifo    ),
        .dout  	(rx_dout_fifo   ),
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
