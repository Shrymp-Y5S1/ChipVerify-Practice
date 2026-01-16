module any_seq #(
    parameter WIDTH =5,
    parameter [WIDTH-1:0] SEQ =5'b10010
)(
    input wire clk,
    input wire rst_n,
    input wire in,
    output wire out
);

    reg [WIDTH-1:0] shift_reg;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            shift_reg <= {WIDTH{1'b0}};
        end else begin
            shift_reg <= {shift_reg[WIDTH-2:0],in};
        end
    end

    assign out = (shift_reg == SEQ);

endmodule
