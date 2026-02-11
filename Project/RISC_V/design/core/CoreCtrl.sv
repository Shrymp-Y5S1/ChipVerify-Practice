module CoreCtrl (
    input clk,
    input rst_sync,

    output logic [31:0] jump_addr,
    output logic        jump,
    output logic        stall_n,    // 0: stall, 1: work
    output logic        flush

);

  always_comb begin
    jump_addr = 0;
    jump      = 0;
    stall_n   = 1;
    flush     = jump;
  end
endmodule
