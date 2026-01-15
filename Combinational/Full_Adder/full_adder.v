// module full_adder(
//     input wire [3:0] a,
//     input wire [3:0] b,
//     input wire cin,
//     output wire [3:0] sum,
//     output wire cout
// );

//     assign {cout, sum} = a+b+cin;

// endmodule

module full_adder(
    input wire [3:0] a,
    input wire [3:0] b,
    input wire cin,
    output reg [3:0] sum,
    output reg cout
);

    always @(*)begin
        {cout, sum} = a+b+cin;
    end

endmodule

