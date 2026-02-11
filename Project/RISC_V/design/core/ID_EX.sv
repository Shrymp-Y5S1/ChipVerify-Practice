module ID_EX
  import RV32I_Inst_Pkg::*;
(
    input clk,
    input rst_sync,
    input stall_n,   // 0: stall, 1: work
    input flush,     // pipleine flush

    // input from ID/EX
    input [31:0] instr_addr_id,
    input [31:0] instr_id,
    input [31:0] operand1_id,
    input [31:0] operand2_id,
    input        reg_wen_id,

    input        ram_load_access_id,
    input        ram_store_access_id,
    input [31:0] ram_load_addr_id,
    input [31:0] ram_store_addr_id,
    input [31:0] ram_store_data_id,

    // output to EX/MEM
    output logic [31:0] instr_addr_ex,
    output logic [31:0] instr_id_ex,
    output logic [31:0] operand1_ex,
    output logic [31:0] operand2_ex,
    output logic        reg_wen_ex,

    output              ram_load_access_ex,
    output              ram_store_access_ex,
    output logic [31:0] ram_load_addr_ex,
    output logic [31:0] ram_store_addr_ex,
    output logic [31:0] ram_store_data_ex

);

  always_ff @(posedge clk) begin
    if (stall_n) begin
      instr_addr_ex     <= instr_addr_id;
      ram_load_addr_ex  <= ram_load_addr_id;
      ram_store_addr_ex <= ram_store_addr_id;
      ram_store_data_ex <= ram_store_data_id;
    end
    if (rst_sync || flush) begin
      instr_id_ex         <= INST_NOP;
      operand1_ex         <= 32'b0;
      operand2_ex         <= 32'b0;
      reg_wen_ex          <= 1'b0;
      ram_load_access_ex  <= 0;
      ram_store_access_ex <= 0;
    end else if (stall_n) begin
      instr_id_ex         <= instr_id;
      operand1_ex         <= operand1_id;
      operand2_ex         <= operand2_id;
      reg_wen_ex          <= reg_wen_id;
      ram_load_access_ex  <= ram_load_access_id;
      ram_store_access_ex <= ram_store_access_id;
    end
  end

endmodule
