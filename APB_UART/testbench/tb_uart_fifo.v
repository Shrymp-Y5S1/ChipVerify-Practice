`timescale 1ns/1ps
module tb_uart_fifo();

    // parameter declaration
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    // input declaration
    reg clk;
    reg rst_n;
    reg [31:0] divisor;
    reg wr_en_tx_fifo;
    reg [DATA_WIDTH-1:0] din_tx_fifo;
    reg rd_en_rx_fifo;

    // output declaration of module tx_fifo
    wire [DATA_WIDTH-1:0] dout_tx_fifo;
    wire full_tx_fifo;
    wire empty_tx_fifo;

    // output declaration of module rx_fifo
    wire [DATA_WIDTH-1:0] dout_rx_fifo;
    wire full_rx_fifo;
    wire empty_rx_fifo;

    // output declaration of module baud_generate
    wire baud_en;
    wire baud_en_16x;

    // output declaration of module uart_rx
    wire [DATA_WIDTH-1:0] rx_data;
    wire rx_ready;
    wire rx_busy;
    wire rx_error;

    // output declaration of module uart_tx
    wire tx;
    wire tx_busy;
    wire data_ack;
    wire tx_ready;

    baud_generate u_baud_generate(
        .clk         	(clk          ),
        .rst_n       	(rst_n        ),
        .divisor     	(divisor      ),
        .baud_en     	(baud_en      ),
        .baud_en_16x 	(baud_en_16x  )
    );

    fifo #(
        .DATA_WIDTH 	(DATA_WIDTH ),
        .ADDR_WIDTH 	(ADDR_WIDTH  ))
    tx_fifo(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .wr_en 	(wr_en_tx_fifo  ),
        .rd_en 	(data_ack  ),
        .din   	(din_tx_fifo    ),
        .dout  	(dout_tx_fifo   ),
        .full  	(full_tx_fifo   ),
        .empty 	(empty_tx_fifo  )
    );

    uart_tx #(
        .DATA_WIDTH  	(DATA_WIDTH      ),
        .PARITY_EN   	(1      ),
        .PARITY_TYPE 	(0  ))
    u_uart_tx(
        .clk      	(clk       ),
        .rst_n    	(rst_n     ),
        .baud_en  	(baud_en   ),
        .tx_data  	(dout_tx_fifo   ),
        .tx_start 	(!tx_busy && !empty_tx_fifo),
        .tx       	(tx        ),
        .tx_busy  	(tx_busy   ),
        .data_ack 	(data_ack  ),
        .tx_ready  	(tx_ready   )
    );

    fifo #(
        .DATA_WIDTH 	(DATA_WIDTH ),
        .ADDR_WIDTH 	(ADDR_WIDTH  ))
    rx_fifo(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .wr_en 	(rx_ready  ),
        .rd_en 	(rd_en_rx_fifo  ),
        .din   	(rx_data    ),
        .dout  	(dout_rx_fifo   ),
        .full  	(full_rx_fifo   ),
        .empty 	(empty_rx_fifo  )
    );

    uart_rx #(
        .DATA_WIDTH  	(DATA_WIDTH      ),
        .PARITY_EN   	(1      ),
        .PARITY_TYPE 	(0  ))
    u_uart_rx(
        .clk         	(clk          ),
        .rst_n       	(rst_n        ),
        .baud_en_16x 	(baud_en_16x  ),
        .rx          	(tx           ),
        .rx_data     	(rx_data      ),
        .rx_ready    	(rx_ready     ),
        .rx_busy     	(rx_busy      ),
        .rx_error    	(rx_error     )
    );

    // clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // write TX FIFO task
    task push_tx_fifo(input [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            if(!full_tx_fifo)begin
                wr_en_tx_fifo <= 1;
                din_tx_fifo <= data;
                @(posedge clk);
                wr_en_tx_fifo <= 0;
                $display("[%0t] TX FIFO Push: %h", $time, data);
            end
        end
    endtask

    // read RX FIFO task
    task pop_rx_fifo();
        begin
            @(posedge clk);
            if(!empty_rx_fifo)begin
                rd_en_rx_fifo <= 1;
                @(posedge clk);
                rd_en_rx_fifo <= 0;
                $display("[%0t] RX FIFO Pop: %h", $time, dout_rx_fifo);
            end
        end
    endtask

    // driver process
    initial begin
        // initialize
        rst_n = 0;
        divisor = 32'd16;
        wr_en_tx_fifo = 0;
        din_tx_fifo = 8'd0;
        rd_en_rx_fifo = 0;

        // release reset
        #100;
        rst_n = 1;
        #100;

        // case 1: single byte transfer test
        $display("[%0t] CASE 1: Single byte transfer test started", $time);
        push_tx_fifo(8'hA5);

        wait(!empty_rx_fifo);
        #50;
        pop_rx_fifo();

        // case 2: burst byte transfer test
        $display("[%0t] CASE 2: Burst byte transfer test started", $time);
        push_tx_fifo(8'h11);
        push_tx_fifo(8'h22);
        push_tx_fifo(8'h33);

        repeat(3)begin
            wait(!empty_rx_fifo);
            #20;
            pop_rx_fifo();
            @(posedge clk);
        end

        wait(!rx_busy);
        #100;
        $display("[%0t] Simulation finished", $time);
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_uart_fifo.fsdb");
        $fsdbDumpvars(0,tb_uart_fifo);
    end

endmodule
