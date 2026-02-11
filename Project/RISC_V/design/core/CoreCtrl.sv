module CoreCtrl (
    input clk,
    input rst_sync,

    input [31:0] jump_addr_ex,
    input        jump_en_ex,

    output logic [31:0] jump_addr,
    output logic        jump,
    output logic        stall_n,    // 0: stall, 1: work
    output logic        flush

);

  always_comb begin
    jump_addr = jump_addr_ex;
    jump      = jump_en_ex;
    stall_n   = 1;
    flush     = jump;
  end
endmodule
