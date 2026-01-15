// Using an assign statement
module fxo_Mux(
    input wire [3:0] in,
    input wire [1:0] sel,
    output wire out
);

    assign out = in[sel];

endmodule

// Using an case statement
// module fxo_Mux(
//     input wire [3:0] in,
//     input wire [1:0] sel,
//     output reg out
// );

//     always @(*)begin
//         case(sel)
//             2'd0:out=in[0];
//             2'd1:out=in[1];
//             2'd2:out=in[2];
//             2'd3:out=in[3];
//             default:out=1'bx;
//         endcase
//     end
// endmodule
