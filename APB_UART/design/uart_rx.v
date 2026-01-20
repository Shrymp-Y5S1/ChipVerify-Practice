module uart_rx #(
    parameter DATA_WIDTH = 8
)(
    input clk,
    input rst_n,
    input baud_en_16x,
    input rx,
    output reg [DATA_WIDTH-1:0] rx_data,
    output reg rx_ready,
    output reg rx_busy,
    output reg rx_error
);

    localparam CNT_WIDTH = $clog2(DATA_WIDTH) + 1;
    localparam IDLE = 3'b000,
               START_BIT = 3'b001,
               DATA_BITS = 3'b011,
               PARITY_BIT = 3'b010,
               STOP_BIT = 3'b110;

    reg [2:0] state;
    reg [CNT_WIDTH-1:0] bit_cnt;
    reg [3:0] oversample_cnt;   // 16x oversampling
    reg [DATA_WIDTH-1:0] rx_data_reg;
    reg rx_sync1, rx_sync2;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            rx_sync1 <= 0;
            rx_sync2 <= 0;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= IDLE;
            rx_data_reg <= 0;
            rx_ready <= 0;
            rx_busy <= 0;
            rx_error <= 0;
            bit_cnt <= 0;
            oversample_cnt <= 0;
        end else begin
            case(state)
                IDLE: begin
                    rx_ready <= 0;
                    rx_error <= 0;
                    if(!rx_sync2)begin
                        state <= START_BIT;
                        rx_busy <= 1;
                        oversample_cnt <= 0;
                    end
                end
                START_BIT: begin
                    if(baud_en_16x)begin
                        oversample_cnt <= oversample_cnt + 1;
                        if(oversample_cnt == 7)begin
                            if(!rx_sync2)begin
                                oversample_cnt <= 0;
                                bit_cnt <= 0;
                                state <= DATA_BITS;
                            end else begin
                                state <= IDLE;
                                rx_busy <= 0;
                                oversample_cnt <= 0;
                            end
                        end
                    end
                end
                DATA_BITS: begin
                    if(baud_en_16x)begin
                        oversample_cnt <= oversample_cnt + 1;
                        if(oversample_cnt == 7)begin
                            rx_data_reg[bit_cnt] <= rx_sync2;
                            oversample_cnt <= 0;
                            if(bit_cnt == DATA_WIDTH - 1)begin
                                state <= PARITY_BIT;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
                PARITY_BIT: begin
                    if(baud_en_16x)begin
                        oversample_cnt <= oversample_cnt + 1;
                        if(oversample_cnt == 7)begin
                            if(rx_sync2 != ^rx_data_reg)begin
                                rx_error <= 1;
                            end
                            oversample_cnt <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end
                STOP_BIT: begin
                    if(baud_en_16x)begin
                        oversample_cnt <= oversample_cnt + 1;
                        if(oversample_cnt == 7)begin
                            if(rx_sync2)begin
                                rx_data <= rx_data_reg;
                                rx_ready <= 1;
                            end else begin
                                rx_error <= 1;
                            end
                            oversample_cnt <= 0;
                            state <= IDLE;
                            rx_busy <= 0;
                        end
                    end
                end
            endcase
        end
    end

endmodule
