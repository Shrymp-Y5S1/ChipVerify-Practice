module Instr_Execute
  import RV32I_Inst_Pkg::*;
(
    // input from ID/EX
    input       [31:0] instr_id_ex,
    input       [31:0] instr_addr_ex,
    input logic [31:0] operand1_ex,
    input logic [31:0] operand2_ex,
    input logic        reg_wen_ex,

    // output to register
    output logic [31:0] reg_wdata,
    output logic [ 4:0] reg_waddr,
    output logic        reg_wen
);

  wire        inst = instr_id_ex;
  // instruction fields
  wire [ 6:0] opcode = inst[6:0];
  wire [ 2:0] funct3 = inst[14:12];
  wire [ 4:0] rs1 = inst[19:15];
  wire [ 4:0] rs2 = inst[24:20];
  wire [ 4:0] rd = inst[11:7];
  wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};


  // execute logic
  wire [31:0] alu_add = operand1_ex + operand2_ex;

  always_comb begin
    reg_wen   = reg_wen_ex;
    reg_waddr = rd;
    reg_wdata = 32'b0;

    unique case (opcode)
      RV32I_OP_I: begin
        unique case (funct3)
          RV32I_ADDI: begin
            reg_wdata = alu_add;
          end
        endcase
      end
    endcase
  end

endmodule
