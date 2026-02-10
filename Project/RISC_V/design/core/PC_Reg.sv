module PC_Reg(
        input clk,
        input rst_sync,
        input stall_n,  // 0: stall, 1: work

        input [31:0] jump_addr,
        input jump_en,
        output logic [31:0] pc
    );

    always_ff @(posedge clk) begin
        if(rst_sync) begin
            pc <= 0;
        end
        else if(jump_en) begin
            pc <= jump_addr;
        end
        else if(stall_n) begin
            pc <= pc + 3'h4;
        end
    end

endmodule
