module axi_idorder #(
        parameter OST_DEPTH = 16,
        parameter ID_WIDTH = 4
    )(
        input clk,
        input rst_n,

        input req_valid,
        input req_ready,
        input [ID_WIDTH-1:0] req_id,
        input [$clog2(OST_DEPTH+1)-1:0] req_ptr,

        input resp_valid,
        input resp_ready,
        input [ID_WIDTH-1:0] resp_id,
        input resp_last,

        output [$clog2(OST_DEPTH+1)-1:0] resp_ptr,
        output reg [OST_DEPTH-1:0] resp_bits
    );

    localparam ID_NUM = 1 << ID_WIDTH;
    localparam PTR_WIDTH = $clog2(OST_DEPTH+1);

    wire [PTR_WIDTH-1:0] fifo_data_out [ID_NUM-1:0];
    wire fifo_empty [ID_NUM-1:0];
    wire fifo_full [ID_NUM-1:0];

    reg fifo_wr [ID_NUM-1:0];
    reg fifo_rd [ID_NUM-1:0];
    reg [PTR_WIDTH-1:0] fifo_data_in [ID_NUM-1:0];

    wire [OST_DEPTH-1:0] fifo_bitmap [ID_NUM-1:0];

    // Instantiate FIFO per ID
    genvar i;
    generate
        for(i = 0; i < ID_NUM; i = i+1) begin: GEN_ID_ORDER_FIFO
            axi_fifo #(
                         .FIFO_DATA_WIDTH 	(PTR_WIDTH),
                         .FIFO_DEPTH      	(OST_DEPTH  ))
                     u_axi_fifo(
                         .clk      	(clk       ),
                         .rst_n    	(rst_n     ),
                         .wr       	(fifo_wr[i]        ),
                         .rd       	(fifo_rd[i]        ),
                         .data_in  	(fifo_data_in[i]   ),
                         .data_out 	(fifo_data_out[i]  ),
                         .empty    	(fifo_empty[i]     ),
                         .full     	(fifo_full[i]      )
                     );
        end
    endgenerate

    // wr on request, rd on last response
    always @(*) begin
        integer j;
        for (j = 0; j < ID_NUM; j = j + 1) begin
            fifo_wr[j] = 1'b0;
            fifo_rd[j] = 1'b0;
            fifo_data_in[j] = {PTR_WIDTH{1'b0}};
        end
        if(req_valid && req_ready) begin
            fifo_wr[req_id] = 1'b1;
            fifo_data_in[req_id] = req_ptr;
        end
        if(resp_valid && resp_ready && ~fifo_empty[resp_id] && resp_last) begin
            fifo_rd[resp_id] = 1'b1;
        end
    end

    // bitmap per ID
    generate
        for (i = 0; i < ID_NUM; i = i + 1) begin: GEN_FIFO_BITMAP
            assign fifo_bitmap[i] = fifo_empty[i] ? {OST_DEPTH{1'b0}} : (1 << fifo_data_out[i]);
        end
    endgenerate

    // ----------------------------------------------------------------
    // Output signals
    // ----------------------------------------------------------------
    assign resp_ptr = fifo_data_out[resp_id];

    // all
    always @(*) begin
        integer k;
        resp_bits = {OST_DEPTH{1'b0}};
        for (k = 0; k < ID_NUM; k = k + 1) begin
            resp_bits = resp_bits | fifo_bitmap[k];
        end
    end

endmodule
