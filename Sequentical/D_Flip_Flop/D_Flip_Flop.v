// module D_Flip_Flop(
//     input wire D,
//     input wire clk,
//     input wire rst_n,
//     output reg Q
// );
//     always @(posedge clk or negedge rst_n)begin
//         if(~rst_n)
//             Q <= 1'b0;
//         else
//             Q <= D;
//     end
// endmodule

module D_Flip_Flop(
    input wire D,
    input wire clk,
    input wire rst_n,
    output reg Q
);
    always @(posedge clk)begin
        if(~rst_n)
            Q <= 1'b0;
        else
            Q <= D;
    end
endmodule
