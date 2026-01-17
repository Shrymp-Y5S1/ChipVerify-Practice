module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter DEPTH = 1 << ADDR_WIDTH
)(
    input wr_clk,
    input rd_clk,
    input rst_n,
    input [DATA_WIDTH-1:0] wr_data,
    input wr_en,
    input rd_en,
    output [DATA_WIDTH-1:0] rd_data,
    output reg full,
    output reg empty
);

    reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;
    reg [ADDR_WIDTH:0] wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_gray;
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync1;
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync2;
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync1;
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync2;

    always @(posedge wr_clk or negedge rst_n)begin
        if(!rst_n)begin
            wr_ptr <= 0;
            wr_ptr_gray <= 0;
        end else begin
            if(wr_en && !full)begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1;
                wr_ptr_gray <= ((wr_ptr + 1) >> 1) ^ (wr_ptr + 1);
            end
        end
    end

    always @(posedge rd_clk or negedge rst_n)begin
        if(!rst_n)begin
            rd_ptr <= 0;
            rd_ptr_gray <= 0;
        end else begin
            if(rd_en && !empty)begin
                rd_ptr <= rd_ptr + 1;
                rd_ptr_gray <= ((rd_ptr + 1) >> 1) ^ (rd_ptr + 1);
            end
        end
    end

    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // sync_wr_ptr
    always @(posedge rd_clk or negedge rst_n)begin
        if(!rst_n)begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    // sync_rd_ptr
    always @(posedge wr_clk or negedge rst_n)begin
        if(!rst_n)begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    always @(posedge wr_clk or negedge rst_n)begin
        if(!rst_n)begin
            full <= 0;
        end else begin
            full <= {~wr_ptr_gray[ADDR_WIDTH:ADDR_WIDTH-1],wr_ptr_gray[ADDR_WIDTH-2:0]}==rd_ptr_gray_sync2;
        end
    end

    always @(posedge rd_clk or negedge rst_n)begin
        if(!rst_n)begin
            empty <= 0;
        end else begin
            empty <= wr_ptr_gray_sync2==rd_ptr_gray;
        end
    end

endmodule
