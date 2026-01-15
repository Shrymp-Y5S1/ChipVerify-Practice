// module pre_encode(
//     input wire [3:0] a,
//     input wire [3:0] b,
//     input wire [3:0] c,
//     input wire [3:0] d,
//     input wire [3:0] sel,
//     output wire [3:0] out
// );

//     assign out = (sel == 4'd0) ? a :
//                  (sel == 4'd1) ? b :
//                  (sel == 4'd2) ? c :
//                                  d ;

// endmodule

module pre_encode(
    input wire [3:0] a,
    input wire [3:0] b,
    input wire [3:0] c,
    input wire [3:0] d,
    input wire [3:0] sel,
    output reg [3:0] out
);

    always @(*)begin
        if(sel == 4'd0)
            out = a;
        else if (sel == 4'd1)
            out = b;
        else if (sel == 4'd2)
            out = c;
        else
            out = d;
    end

endmodule
