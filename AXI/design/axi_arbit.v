// Round-Robin Arbiter
module axi_arbit #(
        parameter ARB_WIDTH = 8
    )(
        input clk,
        input rst_n,
        input [ARB_WIDTH-1:0] queue_i,              // Arbiter queue inputs
        input sche_en,                              // Scheduling enable signal
        output [$clog2(ARB_WIDTH)-1:0] pointer_o    // Grant output (index, combinational
    );

    reg [ARB_WIDTH-1:0] req_power;  // Request priority register

    // 优先级筛选
    wire [ARB_WIDTH-1:0] req_after_power = queue_i & req_power;

    // 查找最低有效位
    wire [ARB_WIDTH-1:0] old_mask = {req_after_power[ARB_WIDTH-2:0] | old_mask[ARB_WIDTH-2:0], 1'b0};  // Old mask for priority
    wire [ARB_WIDTH-1:0] new_mask = {queue_i[ARB_WIDTH-2:0] | new_mask[ARB_WIDTH-2:0], 1'b0};   // New mask for priority
    wire old_grant_work = |req_after_power;    // Check if there is any request after applying priority

    // 仲裁判决
    wire [ARB_WIDTH-1:0] old_grant = (~old_mask) & req_after_power;   // Grant based on old priority
    wire [ARB_WIDTH-1:0] new_grant = (~new_mask) & queue_i;   // Grant based on new priority
    wire [ARB_WIDTH-1:0] grant = old_grant_work ? old_grant : new_grant;

    // 更新优先级
    function automatic [$clog2(ARB_WIDTH)-1:0] onehot_to_index;
        input [ARB_WIDTH-1:0] onehot;
        integer i;
        begin
            onehot_to_index = {$clog2(ARB_WIDTH){1'b0}};
            for (i = 0; i < ARB_WIDTH; i = i + 1) begin
                if (onehot[i]) begin
                    onehot_to_index = i;
                end
            end
        end
    endfunction

    assign pointer_o = (|queue_i) ? onehot_to_index(grant) : {$clog2(ARB_WIDTH){1'b0}};

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            req_power <= {ARB_WIDTH{1'b1}};     // 1 consider, 0 ignore
        end
        else if(sche_en) begin
            if(old_grant_work) begin
                req_power <= old_mask;
            end
            else if(|queue_i) begin
                req_power <= new_mask;
            end
        end
    end

endmodule
