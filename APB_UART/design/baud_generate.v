module baud_generate #(
    // parameter CLOCK_FREQUENCY = 50_000_000,   // 50 MHz
    // parameter BAUD_RATE = 115_200
    parameter CLL_FREQ_INDEX = 0,   // 0:50MHz, 1:25MHz, 2:12.5MHz
    parameter BAUD_RATE_INDEX = 0   // 0:115200, 1:57600, 2:38400, 3:19200, 4:9600
)(
    input clk,
    input rst_n,
    output baud_en,
    output baud_en_16x
);
    wire [31:0] divisor = clock_frequency / baud_rate - 1;
    wire [31:0] divisor_oversample = clock_frequency / (baud_rate * 16) - 1;

    reg [31:0]cnt;
    reg [31:0]cnt_oversample;
    reg [31:0] clock_frequency;
    reg [31:0] baud_rate;

    // Clock frequency
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)
            clock_frequency <= 50_000_000;
        else begin
            case(CLL_FREQ_INDEX)
                2'b00:clock_frequency <= 50_000_000; // 50 MHz
                2'b01:clock_frequency <= 25_000_000; // 25 MHz
                2'b10:clock_frequency <= 12_500_000; // 12.5 MHz
                default:clock_frequency <= 50_000_000;
            endcase
        end
    end

    // Baud rate
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)
            baud_rate <= 115_200;
        else begin
            case(BAUD_RATE_INDEX)
                3'b000:baud_rate <= 115_200;
                3'b001:baud_rate <= 57_600;
                3'b010:baud_rate <= 38_400;
                3'b011:baud_rate <= 19_200;
                3'b100:baud_rate <= 9_600;
                default:baud_rate <= 115_200;
            endcase
	    end
    end

    // Baud rate generator
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt <= 0;
        end else begin
            if(cnt == divisor - 1)begin
                cnt <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end
    assign baud_en = (cnt == divisor-1);

    // 16x oversampling baud rate generator
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt_oversample <= 0;
        end else begin
            if(cnt_oversample == DIVISOR_oversample - 1)begin
                cnt_oversample <= 0;
            end else begin
                cnt_oversample <= cnt_oversample + 1;
            end
        end
    end
    assign baud_en_16x = (cnt_oversample == DIVISOR_oversample-1);

endmodule
