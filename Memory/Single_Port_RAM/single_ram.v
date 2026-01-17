module single_ram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1 << ADDR_WIDTH
)(
    input clk,
    input [ADDR_WIDTH-1:0] addr,    // Address bus
    inout [DATA_WIDTH-1:0] data,    // Data bus
    input cs,                       // Chip select
    input we,                       // 0: read, 1: write
    input oe                        // Output enable
);

    reg [DATA_WIDTH-1 : 0] mem[DEPTH-1 : 0];

    always @(posedge clk)begin
        if(cs & we)begin
            mem[addr] <= data;
        end
    end

    assign data = (cs & ~we & oe) ? mem[addr] : {DATA_WIDTH{1'bz}};

endmodule
