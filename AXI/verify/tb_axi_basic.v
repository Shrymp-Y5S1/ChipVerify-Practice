`timescale 1ns/1ps
module tb_axi_basic();

    reg clk;
    reg rst_n;
    reg rd_en;
    reg wr_en;
    wire rd_req_finish;
    wire wr_req_finish;

    axi_top u_axi_top (
                .clk        ( clk     ),
                .rst_n      ( rst_n   ),
                .rd_en      ( rd_en   ),
                .wr_en      ( wr_en   ),
                .rd_req_finish ( rd_req_finish    ),
                .wr_req_finish ( wr_req_finish    )
            );

    // reset task
    task reset;
        begin
            rd_en = 0;
            wr_en = 0;
            rst_n = 0;
            #(`SIM_PERIOD);
            rst_n = 1;
            #(`SIM_PERIOD*5+`DLY);
            rd_en = 1;
            #(`SIM_PERIOD*5+`DLY);
            wr_en = 1;
        end
    endtask

    // initial
    initial begin
        #(`SIM_PERIOD/2);
        clk = 1'b0;
        reset;
    end

    // clock generation
    always #(`SIM_PERIOD/2) clk = ~clk;

    // read
    always begin
        wait (rd_req_finish == 1);
        #(`SIM_PERIOD * 3);
        rd_en = 0;
    end

    // write
    always begin
        wait (wr_req_finish == 1);
        #(`SIM_PERIOD * 3);
        wr_en = 0;
        #(`SIM_PERIOD * 2000 + `DLY);
        $finish;
    end

    // timeout
    initial begin
        # (`SIM_PERIOD * 10000);
        $display("Time Out");
        $finish;
    end

    // fsdb dump
    initial begin
        $fsdbDumpfile("tb_axi_basic.fsdb");
        $fsdbDumpvars(0,tb_axi_basic, "+all");
    end


endmodule
