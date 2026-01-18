module pipeline_mult (
    input clk,
    input rst_n,
    input [7:0] a,  // add1
    input [7:0] b,  // add2
    input [7:0] c,  // mult
    output reg [16:0] result
);

    reg [7:0] a_reg;
    reg [7:0] b_reg;
    reg [7:0] c_reg;
    reg [7:0] c_reg2;   // 数据对齐
    reg [8:0] sum_reg;
    reg [16:0] mult_reg;

    // stage1: input
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            c_reg <= 8'd0;
        end else begin
            a_reg <= a;
            b_reg <= b;
            c_reg <= c;
        end
    end

    // stage2: add
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            sum_reg <= 9'd0;
            c_reg2 <= 8'd0;
        end else begin
            sum_reg <= a_reg + b_reg;
            c_reg2 <= c_reg;
        end
    end

    // stage3: mult
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            mult_reg <= 17'b0;
        end else begin
            mult_reg <= sum_reg * c_reg2;
        end
    end

    // stage4:output
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            result <= 17'b0;
        end else begin
            result <= mult_reg;
        end
    end

endmodule
