module rst_bridge(
    input clk,
    input rst,
    input async_rst_n,
    output sync_rst_n
);
    reg rst_s1, rst_s2;

    always @(posedge clk or negedge async_rst_n)begin
        if(!async_rst_n)begin
            rst_s1 <= 1'b0;
            rst_s2 <= 1'b0;
        end else begin
            rst_s1 <= 1'b1;
            rst_s2 <= rst_s1;
        end
    end

    assign sync_rst_n = rst_s2;

endmodule
