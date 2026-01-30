module axi_read_master_lite (
    input aclk,
    input aresetn,

    output reg [`ID_WIDTH-1:0] arid,
    output reg [`ADDR_WIDTH-1:0] araddr,
    output reg [7:0] arlen,     // Burst length = arlen + 1
    output reg [2:0] arsize,    // bytes = 1 << arsize
    output reg [1:0] arburst,   // 00: fixed, 01: increment, 10: wrap
    output reg arvalid,

    input arready
);

    // handshake
    always @(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            arvalid <= 1'b0;
        end else begin
            if(!arvalid || arready)
                arvalid <= 1'b1;
            else if(arvalid && arready)
                arvalid <= 1'b0;
        end
    end

    // arid & araddr
    always @(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            arid <= {`ID_WIDTH{1'b0}};
            araddr <= {`ADDR_WIDTH{1'b0}};
        end else begin
            if(!arvalid || arready)begin
                arid <= arid + 1'b1;
                araddr <= araddr + 4; // increment by 4 bytes
            end
        end
    end

    // arlen, arsize, arburst
    always @(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            arlen <= 8'd0;      // burst length = 1
            arsize <= 3'd2;     // 4 bytes
            arburst <= 2'b01;   // increment
        end
    end

endmodule
