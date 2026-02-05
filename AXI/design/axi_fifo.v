module axi_fifo #(
        parameter FIFO_DATA_WIDTH = 4,
        parameter FIFO_DEPTH = 16
    )(
        input clk,
        input rst_n,

        input wr,
        input rd,
        input [FIFO_DATA_WIDTH-1:0] data_in,
        output [FIFO_DATA_WIDTH-1:0] data_out,
        output empty,
        output full
    );

    localparam PTR_WIDTH = $clog2(FIFO_DEPTH+1);

    reg [FIFO_DATA_WIDTH-1:0] fifo[FIFO_DEPTH-1:0];
    reg [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    reg wr_wrap, rd_wrap;   //  FIFO  wrap around indicators

    wire ptr_equal = (wr_ptr == rd_ptr);
    wire wrap_equal = (wr_wrap == rd_wrap);

    assign empty = ptr_equal && wrap_equal;
    assign full = ptr_equal && ~wrap_equal;

    // write pointer logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_ptr <= #`DLY 0;
            wr_wrap <= #`DLY 0;
        end
        else if(wr) begin
            if(wr_ptr == FIFO_DEPTH - 1) begin
                wr_ptr <= #`DLY 0;
                wr_wrap <= #`DLY ~wr_wrap;
            end
            else begin
                wr_ptr <= #`DLY wr_ptr + 1;
            end
        end
    end

    // write data into FIFO
    always @(posedge clk or negedge rst_n) begin
        integer j;
        if(!rst_n) begin
            for (j = 0; j < FIFO_DEPTH; j = j + 1) begin
                fifo[j] <= #`DLY 0;
            end
        end
        else if(wr) begin
            fifo[wr_ptr] <= # `DLY data_in;
        end
    end

    // read pointer logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_ptr <= #`DLY 0;
            rd_wrap <= #`DLY 0;
        end
        else if(rd) begin
            if(rd_ptr == FIFO_DEPTH - 1) begin
                rd_ptr <= #`DLY 0;
                rd_wrap <= #`DLY ~rd_wrap;
            end
            else begin
                rd_ptr <= #`DLY rd_ptr + 1;
            end
        end
    end

    // read data from FIFO
    assign data_out = fifo[rd_ptr];

endmodule
