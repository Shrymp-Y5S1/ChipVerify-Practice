module fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input clk,
    input rst_n,
    input wr_en,
    input rd_en,
    input [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout,
    output full,
    output empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem[DEPTH-1:0];
    reg [ADDR_WIDTH-1:0] wr_prt;
    reg [ADDR_WIDTH-1:0] rd_prt;
    reg [ADDR_WIDTH:0] fifo_cnt;

    // write
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            wr_prt <= 0;
        end else begin
            if(wr_en && !full)begin
                mem[wr_prt] <= din;
                wr_prt <= wr_prt + 1;
            end
        end
    end

    //read
    always @(posedge clk or negedge rst_n)begin
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

    //fifo cnt
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            fifo_cnt <= 0;
        end else begin
            fifo_cnt <= fifo_cnt + (wr_en && !full) -(rd_en && !empty);
        end
    end

    // full & empty
    assign full = fifo_cnt == DEPTH;
    assign empty = !fifo_cnt;

endmodule
