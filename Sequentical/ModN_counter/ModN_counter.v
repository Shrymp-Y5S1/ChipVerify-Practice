module ModN_counter #(
    parameter N =16,
    parameter WIDTH =4
)(
    input clk,
    input rst_n,
    output reg [WIDTH-1:0] cout
);

    always @(posedge clk or negedge rst_n)begin
        if(~rst_n) begin
            cout <= 0;
        end else if(cout == N-1)begin
            cout <= 0;
        end else begin
            cout <= cout + 1;
        end
    end

endmodule
