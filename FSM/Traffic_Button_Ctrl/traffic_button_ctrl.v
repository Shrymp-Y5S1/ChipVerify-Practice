module traffic_button_ctrl(
    input clk,
    input rst_n,
    input ped_btn,
    output reg [1:0] main_light,    // 0:green, 1:yellow, 2:red
    output reg ped_light    // 0:red, 1:green
);

    parameter MAIN_GREEN = 2'b00,
              MAIN_YELLOW= 2'b01,
              MAIN_RED   = 2'b10;

    reg [3:0] clk_cnt;
    reg [1:0] state;
    reg [4:0] ped_btn_cnt;
    reg ped_en;

    // state
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= MAIN_RED;
            clk_cnt <= 4'd0;
        end else begin
            case (state)
                MAIN_GREEN: begin
                    if(ped_en && ped_btn)begin
                        state <= MAIN_YELLOW;
                        clk_cnt <= 4'd0;
                    end else if(clk_cnt == 4'd9)begin
                        state <= MAIN_YELLOW;
                        clk_cnt <= 4'd0;
                    end else begin
                        clk_cnt <= clk_cnt + 4'd1;
                    end
                end
                MAIN_YELLOW: begin
                    if(clk_cnt == 4'd2)begin
                        state <= MAIN_RED;
                        clk_cnt <= 4'd0;
                    end else begin
                        clk_cnt <= clk_cnt + 4'd1;
                    end
                end
                MAIN_RED: begin
                    if(clk_cnt == 4'd9)begin
                        state <= MAIN_GREEN;
                        clk_cnt <= 4'd0;
                    end else begin
                        clk_cnt <= clk_cnt + 4'd1;
                    end
                end
                default: begin
                    state <= MAIN_RED;
                    clk_cnt <= 4'd0;
                end
            endcase
        end
    end

    // ped_button
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            ped_btn_cnt <= 5'd0;
            ped_en <= 1'b1;
        end else begin
            if(ped_en && ped_btn)begin
                ped_en <= 1'b0;
            end else if(!ped_en)begin
                if(ped_btn_cnt == 5'd17)begin
                    ped_btn_cnt <= 5'd0;
                    ped_en <= 1'b1;
                end else begin
                    ped_btn_cnt <= ped_btn_cnt + 5'd1;
                end
            end
        end
    end

    // output
    always @(*)begin
        main_light = state;
        ped_light = (main_light == MAIN_RED) ? 1'b1 : 1'b0;
    end

endmodule
