module uart_rx #(
    parameter DATA_WIDTH = 8,
    parameter PARITY_EN = 1'b1,
    parameter PARITY_TYPE = 1'b0   // 0:even, 1:odd
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
    reg start_flag;
    reg rx_ready_d;
    wire sample_point = (oversample_cnt == 7);  // middle of 16x oversampling
    wire bit_end = (oversample_cnt == 15);  // end of 16x oversampling

    // sync rx input
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            rx_sync1 <= 1;
            rx_sync2 <= 1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // oversample counter
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            oversample_cnt <= 0;
        end else begin
            if(state != IDLE && baud_en_16x)begin
                oversample_cnt <= oversample_cnt + 1;
            end else if(state == IDLE)begin
                oversample_cnt <= 0;
            end
        end
    end

    // uart_rx_data
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= IDLE;
            rx_data_reg <= 0;
            rx_ready <= 0;
            rx_ready_d <= 0;
            rx_busy <= 0;
            rx_error <= 0;
            bit_cnt <= 0;
            start_flag <= 0;
        end else begin
            rx_ready <= 0;
            if(baud_en_16x)begin
                case(state)
                    IDLE: begin
                        rx_ready_d <= 0;
                        rx_error <= 0;
                        start_flag <= 0;
                        rx_data_reg <= 0;
                        if(!rx_sync2)begin
                            state <= START_BIT;
                            rx_busy <= 1;
                        end
                    end
                    START_BIT: begin
                        if(sample_point && !rx_sync2)begin
                            start_flag <= 1;
                        end
                        if(bit_end) begin
                            if(start_flag)begin
                                start_flag <= 0;
                                state <= DATA_BITS;
                                bit_cnt <= 0;
                            end else begin
                                state <= IDLE;
                                rx_busy <= 0;
                            end
                        end
                    end
                    DATA_BITS: begin
                        if(sample_point)begin
                            rx_data_reg[bit_cnt] <= rx_sync2;
                        end
                        if(bit_end) begin
                            if(bit_cnt == DATA_WIDTH - 1)begin
                                if(PARITY_EN)
                                    state <= PARITY_BIT;
                                else
                                    state <= STOP_BIT;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                    PARITY_BIT: begin
                        if(sample_point && (rx_sync2 != (PARITY_TYPE ? ~^rx_data_reg : ^rx_data_reg)))begin
                            rx_error <= 1;
                        end
                        if(bit_end)begin
                            if(rx_error)begin
                                state <= IDLE;
                                rx_busy <= 0;
                            end else begin
                                state <= STOP_BIT;
                            end
                        end
                    end
                    STOP_BIT: begin
                        if(sample_point)begin
                            if(rx_sync2)begin
                                rx_ready_d <= 1;
                            end else begin
                                rx_error <= 1;
                            end
                        end
                        if(bit_end)begin
                            state <= IDLE;
                            rx_busy <= 0;
                            rx_ready <= 1;
                            if(!rx_error && rx_ready_d)begin
                                rx_data <= rx_data_reg;
                            end
                        end
                    end
                endcase
            end
        end
    end

endmodule
