import RV32I_Inst_Pkg::*;

module IF_ID (
    input clk,
    input rst_sync,
    input stall_n,  // 0: stall, 1: work
    input flush,  // pipleine flush

    input [31:0] instr_if,
    input [31:0] instr_addr_if,
    output logic [31:0] instr_if_id,
    output logic [31:0] instr_addr_if_id
);

  logic clear;

  always_ff @(posedge clk) begin
    clear <= rst_sync | flush;
  end
  assign instr_if_id = clear ? INST_NOP : instr_if;  // insert bubble when reset or flush

  always @(posedge clk) begin
    if (stall_n) begin
      instr_addr_if_id <= instr_addr_if;
    end
  end

endmodule

