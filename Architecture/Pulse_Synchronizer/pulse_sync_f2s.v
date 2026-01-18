module pulse_sync_f2s(
    input clk_f,
    input clk_s,
    input rst_n,
    input pulse_f,
    output pulse_s
);

    //===============带反馈的脉冲同步器================//
    reg req_f;
    reg ack_f_s1, ack_f_s2;

    reg req_s_sync1, req_s_sync2, req_s_sync3;
    reg ack_s;

    // req_f
    always @(posedge clk_f or negedge rst_n)begin
        if(!rst_n)begin
            req_f <= 1'b0;
        end else if(pulse_f)begin
            req_f <= 1'b1;
        end else if(ack_f_s2)begin
            req_f <= 1'b0;
        end
    end

    //req_s_sync
    always @(posedge clk_s or negedge rst_n)begin
        if(!rst_n)begin
            req_s_sync1 <= 1'b0;
            req_s_sync2 <= 1'b0;
            req_s_sync3 <= 1'b0;
        end else begin
            req_s_sync1 <= req_f;
            req_s_sync2 <= req_s_sync1;
            req_s_sync3 <= req_s_sync2;
        end
    end

    assign pulse_s = req_s_sync2 && (!req_s_sync3);

    //ack_s
    always @(posedge clk_s or negedge rst_n)begin
        if(!rst_n)begin
            ack_s <= 1'b0;
        end else if(req_s_sync2)begin
            ack_s <= 1'b1;
        end else begin
            ack_s <= 1'b0;
        end
    end

    //ack_f_sync
    always @(posedge clk_f or negedge rst_n)begin
        if(!rst_n)begin
            ack_f_s1 <= 1'b0;
            ack_f_s2 <= 1'b0;
        end else begin
            ack_f_s1 <= ack_s;
            ack_f_s2 <= ack_f_s1;
        end
    end

    //===============电平翻转法================//
    // reg level_f;
    // reg level_s_sync1, level_s_sync2, level_s_sync3;

    // // fast: pulse->level
    // always @(posedge clk_f or negedge rst_n)begin
    //     if(!rst_n)begin
    //         level_f <= 1'b0;
    //     end else if(pulse_f)begin
    //         level_f <= ~level_f;
    //     end
    // end

    // // sync, slow: level->pulse
    // always @(posedge clk_s or negedge rst_n)begin
    //     if(!rst_n)begin
    //         level_s_sync1 <= 1'b0;
    //         level_s_sync2 <= 1'b0;
    //         level_s_sync3 <= 1'b0;
    //     end else begin
    //         level_s_sync1 <= level_f;
    //         level_s_sync2 <= level_s_sync1;
    //         level_s_sync3 <= level_s_sync2;
    //     end
    // end

    // assign pulse_s = level_s_sync2 ^ level_s_sync3;

endmodule
