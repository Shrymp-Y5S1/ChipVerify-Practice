module uart_tx #(
    parameter DATA_WIDTH = 8,
    parameter PARITY_EN = 1'b1,
    parameter PARITY_TYPE = 1'b0   // 0:even, 1:odd
)(
    input clk,
    input rst_n,
    input baud_en,
    input [DATA_WIDTH-1:0] tx_data,
    input tx_start,
    output reg tx,
    output reg tx_busy,
    output reg data_ack,
    output reg tx_ready
);

    localparam CNT_WIDTH = $clog2(DATA_WIDTH) + 1;
    localparam IDLE = 3'b000,
               START_BIT = 3'b001,
               DATA_BITS = 3'b011,
               PARITY_BIT = 3'b010,
               STOP_BIT = 3'b110;

    reg [2:0] state;
    reg [CNT_WIDTH-1:0] bit_cnt;
    reg [DATA_WIDTH-1:0] tx_data_reg;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= 0;
            tx <= 1;
            tx_busy <= 0;
            tx_data_reg <= 0;
            bit_cnt <= 0;
            data_ack <= 0;
            tx_ready <= 0;
        end else begin
            tx_ready <= 0;
            case(state)
                IDLE:begin
                    if(tx_start)begin
                        tx_data_reg <= tx_data;
                        state <= START_BIT;
                        tx_busy <= 1;
                        data_ack <= 1;
                    end else begin
                        tx <= 1;
                        state <= IDLE;
                        tx_busy <= 0;
                    end
                end
                START_BIT:begin
                    data_ack <= 0;
                    if(baud_en)begin
                        tx <= 0;
                        state <= DATA_BITS;
                        bit_cnt <= 0;
                    end
                end
                DATA_BITS:begin
                    if(baud_en)begin
                        tx <= tx_data_reg[bit_cnt];
                        if(bit_cnt == DATA_WIDTH - 1)
                            if(PARITY_EN)
                                state <= PARITY_BIT;
                            else
                                state <= STOP_BIT;
                        else
                            bit_cnt <= bit_cnt + 1;
                    end
                end
                PARITY_BIT:begin
                    if(baud_en)begin
                        tx <= (PARITY_TYPE ? ~^tx_data_reg : ^tx_data_reg);
                        state <= STOP_BIT;
                    end
                end
                STOP_BIT:begin
                    if(baud_en)begin
                        tx <= 1;
                        state <= IDLE;
                        tx_busy <= 0;
                        tx_ready <= 1;
                    end
                end
            endcase
        end
    end

endmodule
