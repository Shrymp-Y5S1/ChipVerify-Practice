`timescale 1ns/1ps
module tb_axi_basic();

    reg clk;
    reg rst_n;

    axi_top u_axi_top (
                .clk        ( clk     ),
                .rst_n      ( rst_n   )
            );

    wire error = u_axi_top.u_axi_slv.rd_data_err;

    initial begin
        forever begin
            wait (error == 1);
            rst_n = 0;
            #(`SIM_PERIOD * 5);
            $finish;
        end
    end

    // clock generation
    initial begin
        #(`SIM_PERIOD/2);
        clk = 0;
        forever
            #(`SIM_PERIOD/2) clk = ~clk;
    end

    // reset task
    task reset;
        begin
            rst_n = 0;
            #(`SIM_PERIOD);
            # 0.1;
            rst_n = 1;
        end
    endtask

    initial begin
        reset;
        #(`SIM_PERIOD * 1000);
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_axi_basic.fsdb");
        $fsdbDumpvars(0,tb_axi_basic);
    end


endmodule
