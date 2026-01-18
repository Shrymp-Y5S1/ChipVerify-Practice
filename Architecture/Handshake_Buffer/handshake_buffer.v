module handshake_buffer #(
    parameter WIDTH = 8
)(
    input clk,
    input rst_n,
    input s_valid,
    output s_ready,
    input [WIDTH-1:0] s_data,
    input m_ready,
    output reg m_valid,
    output reg [WIDTH-1:0] m_data
);

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            m_data <= {WIDTH{1'b0}};
            m_valid <= 1'b0;
        end else begin
            if(s_ready)begin
                m_valid <= s_valid;
                if(s_valid)begin
                    m_data <= s_data;
                end
            end
        end
    end

    assign s_ready = !m_valid || m_ready;

endmodule
