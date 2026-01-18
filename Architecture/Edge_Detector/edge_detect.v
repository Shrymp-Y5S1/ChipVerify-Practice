module edge_detect(
    input clk,
    input rst_n,
    input sig_in,
    output pos_edge,
    output neg_edge
);

    // 12防止异步的亚稳态，3用于检测边沿
    reg sig_in_reg1;
    reg sig_in_reg2;
    reg sig_in_reg3;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            sig_in_reg1 <= 0;
            sig_in_reg2 <= 0;
            sig_in_reg3 <= 0;
        end else begin
            sig_in_reg1 <= sig_in;
            sig_in_reg2 <= sig_in_reg1;
            sig_in_reg3 <= sig_in_reg2;
        end
    end

    assign pos_edge =sig_in_reg2 && (!sig_in_reg3);
    assign neg_edge =sig_in_reg3 && (!sig_in_reg2);

endmodule
