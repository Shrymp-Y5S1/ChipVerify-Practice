// uart loopback testbench

`timescale 1ns/1ps
module tb_uart_core();
    // signal declaration
    reg clk;
    reg rst_n;
    reg [31:0] divisor;
    reg [7:0] tx_data;
    reg tx_start;

    // out from baud generator
    wire baud_en;
    wire baud_en_16x;
    // out from uart_tx
    wire tx;
    wire tx_busy;
    wire data_ack;
    // out from uart_rx
    wire [7:0] rx_data;
    wire rx_ready;
    wire rx_busy;
    wire rx_error;

    baud_generate u_baud_generate(
        .clk         	(clk          ),
        .rst_n       	(rst_n        ),
        .divisor     	(divisor      ),
        .baud_en     	(baud_en      ),
        .baud_en_16x 	(baud_en_16x  )
    );

    uart_rx #(
        .DATA_WIDTH  	(8      ),
        .PARITY_EN   	(1      ),
        .PARITY_TYPE 	(0  ))  // 0: even, 1: odd
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

    uart_tx #(
        .DATA_WIDTH  	(8      ),
        .PARITY_EN   	(1      ),
        .PARITY_TYPE 	(0  ))  // 0: even, 1: odd
    u_uart_tx(
        .clk      	(clk       ),
        .rst_n    	(rst_n     ),
        .baud_en  	(baud_en   ),
        .tx_data  	(tx_data   ),
        .tx_start 	(tx_start  ),
        .tx       	(tx        ),
        .tx_busy  	(tx_busy   ),
        .data_ack 	(data_ack  )
    );

    // clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // drive signals
    initial begin
        // initialize
        rst_n = 0;
        divisor = 434;
        tx_data = 8'h0;
        tx_start = 0;

        // release reset
        # 100;
        rst_n = 1;
        # 100;

        // send first byte
        wait(!tx_busy);
        @(posedge clk);
        tx_data = 8'hA5;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        // wait receive complete
        wait(rx_ready);
        if(rx_data == 8'hA5 && !rx_error)
            $display("[%0t] TEST PASSED: Received 0xA5 correctly!", $time);
        else
            $display("[%0t] TEST FAILED: Received %h with error %b", $time, rx_data, rx_error);

        // send second byte
        wait(!tx_busy);
        @(posedge clk);
        tx_data = 8'h5A;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        wait(rx_ready);
        if(rx_data == 8'h5A && !rx_error)
            $display("[%0t] TEST PASSED: Received 0x5A correctly!", $time);
        else
            $display("[%0t] TEST FAILED: Received %h with error %b", $time, rx_data, rx_error);

        divisor = 868;  // change baud rate to 57600
        // send third byte with different baud rate
        wait(!tx_busy);
        @(posedge clk);
        tx_data = 8'h88;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        wait(rx_ready);
        if(rx_data == 8'h88 && !rx_error)
            $display("[%0t] TEST PASSED: Received 0x88 correctly!", $time);
        else
            $display("[%0t] TEST FAILED: Received %h with error %b", $time, rx_data, rx_error);

        # 100000;
        $display("[%0t] Simulation Finished", $time);
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_uart_core.fsdb");
        $fsdbDumpvars(0, tb_uart_core);
    end

endmodule
