`timescale 1ns/1ps
module tb_fifo();
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    // signal declaration
    reg clk;
    reg rst_n;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] din;

    wire [DATA_WIDTH-1:0] dout;
    wire full;
    wire empty;

    fifo #(
        .DATA_WIDTH 	(8  ),
        .ADDR_WIDTH 	(4  ))
    u_fifo(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .wr_en 	(wr_en  ),
        .rd_en 	(rd_en  ),
        .din   	(din    ),
        .dout  	(dout   ),
        .full  	(full   ),
        .empty 	(empty  )
    );

    // clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // driver process
    initial begin
        // initialization
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        din = 0;

        // release reset
        # 100;
        rst_n = 1;
        # 100;

        // write until full
        $display("[%0t] Starting Write to Full Test...", $time);
        repeat(16) begin
            @(posedge clk);
            if(!full) begin
                wr_en = 1;
                din = din + 1;
            end
        end
        @(posedge clk);
        wr_en = 0;
        #20;
        if(full)
            $display("[%0t] FIFO is Full as Expected.", $time);
        else
            $display("[%0t] ERROR: FIFO is NOT Full!", $time);

        // overflow write attempt
        $display("[%0t] Starting Overflow Write Test...", $time);
        @(posedge clk);
        wr_en = 1;
        din = 8'hFF;
        @(posedge clk);
        wr_en = 0;
        #20;
        if(full && dout != 8'hFF)
            $display("[%0t] Overflow Write Prevented as Expected.", $time);
        else
            $display("[%0t] ERROR: Overflow Write Occurred!", $time);

        // read until empty
        $display("[%0t] Starting Read to Empty Test...", $time);
        repeat(16) begin
            @(posedge clk);
            if(!empty)begin
                rd_en = 1;
                $display("[%0t] Reading data: %h", $time, dout);
            end
        end
        @(posedge clk);
        rd_en = 0;
        #20;
        if(empty)
            $display("[%0t] FIFO is Empty as Expected.", $time);
        else
            $display("[%0t] ERROR: FIFO is NOT Empty!", $time);

        // underflow read attempt
        $display("[%0t] Starting Underflow Read Test...", $time);
        @(posedge clk);
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        #20;
        if(empty)
            $display("[%0t] Underflow Read Prevented as Expected.", $time);
        else
            $display("[%0t] ERROR: Underflow Read Occurred!", $time);

        // R/W test
        $display("[%0t] Starting Simultaneous Read/Write Test...", $time);
        @(posedge clk);
        wr_en = 1;
        din = 8'hAA;
        #20;
        @(posedge clk);
        wr_en = 1;
        din = 8'hBB;
        rd_en = 1;
        if(dout == 8'hAA)
            $display("[%0t] Simultaneous Read/Write Successful: Read %h", $time, dout);
        else
            $display("[%0t] ERROR: Simultaneous Read/Write Failed: Read %h", $time, dout);
        @(posedge clk);
        wr_en = 0;
        rd_en = 0;

        #100;
        $display("[%0t] FIFO Simulation Finished", $time);
        $finish;
    end

    initial begin
        $dumpfile("tb_fifo.fsdb");
        $dumpvars(0, tb_fifo);
    end

endmodule
