module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter DEPTH = 1 << ADDR_WIDTH
)(
    input clk,
    input rst_n,
    input wr_en,
    input rd_en,
    input [DATA_WIDTH-1 : 0] din,
    output reg [DATA_WIDTH-1 : 0] dout,
    output full,
    output empty
);

    reg [DATA_WIDTH-1 : 0] mem [0 : DEPTH-1];
    reg [ADDR_WIDTH-1 : 0] wr_prt;
    reg [ADDR_WIDTH-1 : 0] rd_prt;
    reg [ADDR_WIDTH : 0] fifo_cnt;

    // write
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            wr_prt <= 0;
        end else begin
            if(wr_en && !full)begin
                mem[wr_prt] <= din;
                wr_prt <= wr_prt + 1;
            end
        end
    end

    // read
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            rd_prt <= 0;
            dout <= 0;
        end else begin
            if(rd_en && !empty)begin
                dout <= mem[rd_prt];
                rd_prt <= rd_prt + 1;
            end
        end
    end

    // fifo cnt
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            fifo_cnt <= 0;
        end else begin
            case({wr_en && !full, rd_en && !empty})
                2'b01 :begin    // only read
                    fifo_cnt <= fifo_cnt - 1;
                end
                2'b10 :begin    // only write
                    fifo_cnt <= fifo_cnt + 1;
                end
                default : begin  // both or none
                    fifo_cnt <= fifo_cnt;
                end
            endcase
            // fifo_cnt <= fifo_cnt + (wr_en && !full) - (rd_en && !empty);
        end
    end

    // full & empty
    assign full = fifo_cnt == DEPTH;
    assign empty = fifo_cnt == 0;

endmodule
