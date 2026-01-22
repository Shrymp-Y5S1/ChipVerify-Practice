`timescale 1ns/1ps
module tb_apb_sys();

    // parameter declaration
    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;
    parameter WAIT_STATES = 1;    // 0: no wait states, 1: wait state

    // input declaration
    reg PCLK;
    reg PRESETn;
    reg [ADDR_WIDTH-1:0] PADDR;
    reg PSELx;
    reg PENABLE;
    reg PWRITE;
    reg [DATA_WIDTH-1:0] PWDATA;
    reg rx;

    // output declaration of module apb_if
    wire PREADY;
    wire [DATA_WIDTH-1:0] PRDATA;
    wire PSLVERR;
    wire tx;

    reg [DATA_WIDTH-1:0] read_val;
    reg [DATA_WIDTH-1:0] send_val;
    integer i;


    localparam REG_UART_DATA = 4'h0,
               REG_UART_CTRL = 4'h4,
               REG_UART_STAT = 4'h8,
               REG_UART_INT = 4'hc;

    apb_if #(
        .ADDR_WIDTH  	(ADDR_WIDTH      ),
        .DATA_WIDTH  	(DATA_WIDTH      ),
        .WAIT_STATES 	(WAIT_STATES     ))
    u_apb_if(
        .PCLK    	(PCLK     ),
        .PRESETn 	(PRESETn  ),
        .PADDR   	(PADDR    ),
        .PSELx   	(PSELx    ),
        .PENABLE 	(PENABLE  ),
        .PWRITE  	(PWRITE   ),
        .PWDATA  	(PWDATA   ),
        .rx      	(tx       ),    // loopback for testing
        .PREADY  	(PREADY   ),
        .PRDATA  	(PRDATA   ),
        .PSLVERR 	(PSLVERR  ),
        .tx      	(tx       )
    );

    // clock generation
    initial begin
        PCLK = 0;
        forever #10 PCLK = ~PCLK; // 20ns clock period
    end

    // task: APB simulation
    // write operation
    task apb_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge PCLK);
            PSELx <= 1;
            PWRITE <= 1;
            PADDR <= addr;
            PWDATA <= data;
            PENABLE <= 0;
            @(posedge PCLK);
            PENABLE <= 1;
            wait(PREADY);
            @(posedge PCLK);
            PSELx <= 0;
            PENABLE <= 0;
        end
    endtask

    // read operation
    task apb_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        begin
            @(posedge PCLK);
            PSELx <= 1;
            PWRITE <= 0;
            PADDR <= addr;
            PENABLE <= 0;
            @(posedge PCLK);
            PENABLE <= 1;
            wait(PREADY);
            #1;
            data <= PRDATA;
            @(posedge PCLK);
            PSELx <= 0;
            PENABLE <= 0;
        end
    endtask

    initial begin
        // initialize
        PCLK = 0;
        PRESETn = 0;
        PSELx = 0;
        PENABLE = 0;
        PWRITE = 0;
        PADDR = 0;
        PWDATA = 0;
        rx = 1;

        // reset release
        #100
        PRESETn = 1;
        #100

        // config UART reg:
        // enable uart, set clk = 50MHz, baud = 115200, enable tx
        // Control register, en:[0], IE:[1], clk_freq_index:[3:2], baud_rate_index:[6:4], tx_en:[7]
        $display("[%0t] Config: Setting UART CTRL register...", $time);
        apb_write(REG_UART_CTRL, 8'h81); // en_sys=1, clk_freq_index=0 (50MHz), baud_rate_index=0 (115200), tx_en=1

        // -------------------------------------------------------------------------
        // Test Case 1: Single Byte Transmission
        // -------------------------------------------------------------------------
        $display("\n---------------------------------------------------");
        $display("[%0t] Test Case 1: Single Byte Loopback Test", $time);
        // send data
        $display("[%0t] TX: Sending 0x55 via APB...", $time);
        apb_write(REG_UART_DATA, 8'h55);

        // read back status
        // Status register, rx_empty:[0], rx_ready:[1], rx_busy:[2], rx_err:[3], tx_full:[4], tx_ready:[5], tx_busy:[6]
        read_val = 8'h0;

        // Wait for both TX done and RX done (since loopback)
        while(read_val != 8'h03)begin
            apb_read(REG_UART_INT, read_val);
            #1000;
        end
        $display("[%0t] STAT: Interrupt detected (TX done + RX done)!", $time);

        // read received data
        apb_read(REG_UART_DATA, read_val);
        $display("[%0t] RX: Data received via APB: 0x%h", $time, read_val);

        if (read_val === 8'h55)
            $display("[%0t] SUCCESS: Data match!", $time);
        else
            $display("[%0t] ERROR: Data mismatch! Expected 0x55, Got 0x%h", $time, read_val);

        // verify interrupt W1C
        apb_read(REG_UART_INT, read_val);
        $display("[%0t] INT_REG: Before Clear = %b", $time, read_val[1:0]);
        apb_write(REG_UART_INT, 8'h03) ; // clear both rx_done and tx_done
        apb_read(REG_UART_INT, read_val);
        $display("[%0t] INT_REG: After Clear = %b", $time, read_val[1:0]);

        // -------------------------------------------------------------------------
        // Test Case 2: Multiple Random Bytes Loopback
        // -------------------------------------------------------------------------
        $display("\n---------------------------------------------------");
        $display("[%0t] Test Case 2: 5 Random Bytes Loopback Test", $time);

        for (i = 0; i < 5; i = i + 1) begin
            send_val = $random;
            $display("[%0t] Iteration %0d: Sending 0x%h...", $time, i, send_val);

            apb_write(REG_UART_DATA, send_val);

            // Wait for completion
            read_val = 8'h0;
            while(read_val != 8'h03) begin
                apb_read(REG_UART_INT, read_val);
                #1000;
            end

            // Read received data
            apb_read(REG_UART_DATA, read_val);
            $display("[%0t] Iteration %0d: Received 0x%h", $time, i, read_val);

            if (read_val === send_val)
                $display("[%0t] MATCH", $time);
            else begin
                $display("[%0t] MISMATCH! Expected 0x%h, Got 0x%h", $time, send_val, read_val);
                $finish;
            end

            // Clear interrupts for next round
            apb_write(REG_UART_INT, 8'h03);
            #1000; // Small delay
        end
        $display("[%0t] SUCCESS: All random bytes matched!", $time);

        // -------------------------------------------------------------------------
        // Test Case 3: FIFO Empty/Full Check
        // -------------------------------------------------------------------------
        $display("\n---------------------------------------------------");
        $display("[%0t] Test Case 3: FIFO Boundary (Empty/Full) Test", $time);

        // 3a. Check RX FIFO is Empty
        apb_read(REG_UART_STAT, read_val);
        if (read_val[0] === 1'b1)
            $display("[%0t] PASS: RX FIFO is initially empty.", $time);
        else begin
            $display("[%0t] FAIL: RX FIFO should be empty! Stat=0x%h", $time, read_val);
            $finish;
        end

        // 3b. Test TX FIFO Full
        // Disable TX first so data stays in FIFO
        $display("[%0t] Disable TX to fill FIFO...", $time);
        apb_write(REG_UART_CTRL, 8'h01); // en_sys=1, tx_en=0

        $display("[%0t] Filling TX FIFO with 16 bytes...", $time);
        for (i = 0; i < 16; i = i + 1) begin
             apb_write(REG_UART_DATA, i); // Write value 0..15
        end

        // Check TX Full Status
        apb_read(REG_UART_STAT, read_val);
        // Bit 4 is tx_full
        if (read_val[4] === 1'b1)
            $display("[%0t] PASS: TX FIFO reports FULL after 16 writes.", $time);
        else begin
            $display("[%0t] FAIL: TX FIFO should be FULL! Stat=0x%h", $time, read_val);
            //$finish; // Don't abort yet, see what happens
        end

        // 3c. Drain FIFO (Enable TX) and Verify Data
        $display("[%0t] Re-enable TX to drain FIFO...", $time);
        apb_write(REG_UART_CTRL, 8'h81); // en_sys=1, tx_en=1

        // Receive 16 bytes
        $display("[%0t] Reading back 16 bytes...", $time);
        for (i = 0; i < 16; i = i + 1) begin
            // Poll for RX Ready (Bit 1) or !RX Empty (Bit 0 low)
            read_val = 8'h00;
            // Timeout loop could be added here
            while(read_val[1] == 1'b0) begin
                apb_read(REG_UART_STAT, read_val);
                #1000;
            end

            // Read Data
            apb_read(REG_UART_DATA, read_val);
            // Verify
            if (read_val === (i & 8'hFF))
                $display("[%0t] RX Byte %0d Match: 0x%h", $time, i, read_val);
            else begin
                 $display("[%0t] RX Byte %0d MISMATCH! Exp:0x%h Got:0x%h", $time, i, i, read_val);
                 $finish;
            end

            // Clear RX Interrupt (optional, depending on design if it blocks)
            // Assuming RX Ready clears on read or we just need to read.
            // But if there is an interrupt bit latching, we might want to clear it occasionally.
            // The logic checks STATUS register bit 1 (rx_ready) which usually reflects FIFO state directly,
            // whereas INT register latches events.
        end
        $display("[%0t] PASS: All 16 bytes received correctly.", $time);

        // 3d. Check RX Empty Again
        apb_read(REG_UART_STAT, read_val);
        if (read_val[0] === 1'b1)
            $display("[%0t] PASS: RX FIFO is empty after reading all data.", $time);
        else
            $display("[%0t] FAIL: RX FIFO should be empty! Stat=0x%h", $time, read_val);

        #500;
        $display("\n---------------------------------------------------");
        $display("[%0t] Testbench Completed Successfully!", $time);
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_apb_sys.fsdb");
        $fsdbDumpvars(0, tb_apb_sys);
    end

endmodule
