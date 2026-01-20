module baud_generate #(
    parameter CLOCK_FREQUENCY = 50_000_000,   // 50 MHz
    parameter BAUD_RATE = 115_200
    // parameter CLL_FREQ_INDEX = 0,   // 0:50MHz, 1:25MHz, 2:12.5MHz
    // parameter BAUD_RATE_INDEX = 0   // 0:115200, 1:57600, 2:38400, 3:19200, 4:9600
)(
    input clk,
    input rst_n,
    output baud_en,
    output baud_en_16x
);
    localparam DIVISOR = CLOCK_FREQUENCY / BAUD_RATE - 1;
    localparam DIVISOR_OVERSAMPLE = CLOCK_FREQUENCY / (BAUD_RATE * 16) - 1;

    reg [31:0]cnt;
    reg [31:0]cnt_oversample;

    // Baud rate generator
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt <= 0;
        end else begin
            if(cnt == DIVISOR)begin
                cnt <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end
    assign baud_en = (cnt == DIVISOR);

    // 16x oversampling baud rate generator
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt_oversample <= 0;
        end else begin
            if(cnt_oversample == DIVISOR_OVERSAMPLE)begin
                cnt_oversample <= 0;
            end else begin
                cnt_oversample <= cnt_oversample + 1;
            end
        end
    end
    assign baud_en_16x = (cnt_oversample == DIVISOR_OVERSAMPLE);

endmodule
