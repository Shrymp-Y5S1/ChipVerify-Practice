// 严格按照 AMBA APB Protocol Specification 编写的 APB 接口模块

module apb_if #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 8,   // 8/16/32 bits wide
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
    output tx,
    output dma_tx_req,
    output dma_rx_req
);

    // output declaration of module baud_generate
    wire baud_en;
    wire baud_en_16x;

    // output declaration of module fifo_tx
    wire [DATA_WIDTH-1:0] tx_dout_fifo;
    wire full_tx_fifo;
    wire empty_tx_fifo;
    wire [ADDR_WIDTH:0] cnt_tx_fifo;

    // output declaration of module uart_tx
    wire tx_busy;
    wire data_ack;
    wire tx_ready;

    // output declaration of module fifo_rx
    wire [DATA_WIDTH-1:0] rx_din_fifo;
    wire [DATA_WIDTH-1:0] rx_dout_fifo;
    wire full_rx_fifo;
    wire empty_rx_fifo;
    wire [ADDR_WIDTH:0] cnt_rx_fifo;

    // output declaration of module uart_rx
    wire rx_ready;
    wire rx_busy;
    wire rx_error;

    // clock frequency and baud rate
    reg [31:0] divisor;

    // output declaration of module reg_map
    wire en_sys;
    wire [1:0] clk_freq_index;
    wire [2:0] baud_rate_index;
    wire [DATA_WIDTH-1:0] din_tx_fifo;
    wire wr_en_tx_fifo;
    wire rd_en_rx_fifo;
    wire tx_en;
    // wire dma_tx_req;
    // wire dma_rx_req;

    reg_map #(
        .ADDR_WIDTH  	(ADDR_WIDTH      ),
        .DATA_WIDTH  	(DATA_WIDTH      ),
        .WAIT_STATES 	(WAIT_STATES  ))
    u_reg_map(
        .PCLK            	(PCLK             ),
        .PRESETn         	(PRESETn          ),
        .PADDR           	(PADDR            ),
        .PSELx           	(PSELx            ),
        .PENABLE         	(PENABLE          ),
        .PWRITE          	(PWRITE           ),
        .PWDATA          	(PWDATA           ),
        .full_tx_fifo    	(full_tx_fifo     ),
        .cnt_tx_fifo        (cnt_tx_fifo      ),
        .dout_rx_fifo    	(rx_dout_fifo     ),
        .empty_rx_fifo   	(empty_rx_fifo    ),
        .cnt_rx_fifo        (cnt_rx_fifo      ),
        .tx_busy         	(tx_busy          ),
        .tx_ready        	(tx_ready         ),
        .rx_error        	(rx_error         ),
        .rx_ready        	(rx_ready         ),
        .rx_busy         	(rx_busy          ),
        .PREADY          	(PREADY           ),
        .PRDATA          	(PRDATA           ),
        .PSLVERR         	(PSLVERR          ),
        .en_sys          	(en_sys           ),
        .clk_freq_index  	(clk_freq_index   ),
        .baud_rate_index 	(baud_rate_index  ),
        .din_tx_fifo     	(din_tx_fifo      ),
        .wr_en_tx_fifo   	(wr_en_tx_fifo    ),
        .dma_tx_req      	(dma_tx_req       ),
        .rd_en_rx_fifo   	(rd_en_rx_fifo    ),
        .dma_rx_req      	(dma_rx_req       ),
        .tx_en           	(tx_en            )
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
        .rst_n       	(PRESETn && en_sys      ),
        .divisor        (divisor      ),
        .baud_en     	(baud_en      ),
        .baud_en_16x 	(baud_en_16x  )
    );

    fifo #(
        .DATA_WIDTH 	(DATA_WIDTH  ),
        .ADDR_WIDTH 	(ADDR_WIDTH  ))
    tx_fifo(
        .clk   	(PCLK           ),
        .rst_n 	(PRESETn && en_sys      ),
        .wr_en 	(wr_en_tx_fifo          ),
        .rd_en 	(data_ack       ),
        .din   	(din_tx_fifo    ),
        .dout  	(tx_dout_fifo   ),
        .full  	(full_tx_fifo),
        .empty 	(empty_tx_fifo  ),
        .cnt   	(cnt_tx_fifo)
    );

    uart_tx #(
        .DATA_WIDTH  	(DATA_WIDTH      ),
        .PARITY_EN   	(1      ),
        .PARITY_TYPE 	(0  ))
    u_uart_tx(
        .clk      	(PCLK           ),
        .rst_n    	(PRESETn && en_sys      ),
        .baud_en  	(baud_en        ),
        .tx_data  	(tx_dout_fifo   ),
        .tx_start 	(!empty_tx_fifo && !tx_busy && tx_en),
        .tx       	(tx             ),
        .tx_busy  	(tx_busy        ),
        .data_ack 	(data_ack       ),
        .tx_ready  	(tx_ready       )
    );


    fifo #(
        .DATA_WIDTH 	(DATA_WIDTH  ),
        .ADDR_WIDTH 	(ADDR_WIDTH  ))
    rx_fifo(
        .clk   	(PCLK           ),
        .rst_n 	(PRESETn && en_sys      ),
        .wr_en 	(rx_ready       ),
        .rd_en 	(rd_en_rx_fifo  ),
        .din   	(rx_din_fifo    ),
        .dout  	(rx_dout_fifo   ),
        .full  	(full_rx_fifo   ),
        .empty 	(empty_rx_fifo  ),
        .cnt    (cnt_rx_fifo)
    );

    uart_rx #(
        .DATA_WIDTH 	(DATA_WIDTH  ),
        .PARITY_EN   	(1  ),
        .PARITY_TYPE 	(0  ))
    u_uart_rx(
        .clk         	(PCLK         ),
        .rst_n       	(PRESETn && en_sys      ),
        .baud_en_16x 	(baud_en_16x  ),
        .rx          	(tx           ),
        .rx_data     	(rx_din_fifo  ),
        .rx_ready    	(rx_ready     ),
        .rx_busy     	(rx_busy      ),
        .rx_error    	(rx_error     )
    );

endmodule
