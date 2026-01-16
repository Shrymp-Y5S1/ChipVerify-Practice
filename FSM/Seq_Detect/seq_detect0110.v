module seq_detect0110 (
    input wire clk,
    input wire rst_n,
    input wire in,
    output reg out
);

    parameter S0 = 2'b00,   //IDLE
              S1 = 2'b01,   //0
              S2 = 2'b10,   //01
              S3 = 2'b11;   //011

    reg [1:0] curr_state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            curr_state <= S0;
        end else begin
            curr_state <= next_state;
        end
    end

    always @(*)begin
        case(curr_state)
            S0 :next_state = (in == 1'b0) ? S1 : S0;
            S1 :next_state = (in == 1'b1) ? S2 : S1;
            S2 :next_state = (in == 1'b1) ? S3 : S1;
            S3 :next_state = (in == 1'b0) ? S1 : S0;
            default :next_state = S0;
        endcase
    end

    always @(*)begin
        if(curr_state == S3 && !in)begin
            out = 1'b1;
        end else begin
            out = 1'b0;
        end
    end

endmodule
