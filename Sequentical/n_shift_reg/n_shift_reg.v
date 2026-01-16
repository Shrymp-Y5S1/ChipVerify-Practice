module n_shift_reg #(
    parameter N = 4
)(
    input wire clk,
    input wire rst_n,
    input wire dir, // 0: left, 1: right
    input wire in_bit,
    output reg [N-1:0] out_bits
);

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            out_bits <= {N{1'b0}};
        end else begin
            if(dir)begin
                out_bits <= {in_bit,out_bits[N-1:1]};
            end else begin
                out_bits <= {out_bits[N-2:0],in_bit};
            end
        end
    end

endmodule
