module Instr_Decoder
  import RV32I_Inst_Pkg::*;
(
    // input from IF/ID
    input [31:0] instr_if_id,
    input [31:0] instr_addr_if_id,

    // in/output to register
    output logic [ 4:0] reg1_raddr,
    output logic [ 4:0] reg2_raddr,
    input        [31:0] reg1_rdata,
    input        [31:0] reg2_rdata,

    // output to ID/EX
    output logic [31:0] instr_addr_id,
    output logic [31:0] instr_id,
    output logic [31:0] operand1_id,
    output logic [31:0] operand2_id,
    output logic        reg_wen_id
);

  assign instr_id      = instr_if_id;
  assign instr_addr_id = instr_addr_if_id;

  // instruction fields
  wire [31:0] inst = instr_if_id;
  wire [ 6:0] opcode = inst[6:0];
  wire [ 2:0] funct3 = inst[14:12];
  wire [ 4:0] rs1 = inst[19:15];
  wire [ 4:0] rs2 = inst[24:20];
  wire [ 4:0] shamt = rs2;

  // immediate values
  wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
  wire [31:0] imm_u = {inst[31:12], 12'b0};
  wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  wire [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
  wire [31:0] imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

  // decode logic
  always_comb begin
    reg1_raddr  = rs1;
    reg2_raddr  = rs2;
    operand1_id = 0;
    operand2_id = 0;
    reg_wen_id  = 0;

    unique case (opcode)
      RV32I_OP_LUI: begin
        reg_wen_id  = 1;
        operand1_id = 0;
        operand2_id = imm_u;
      end
      RV32I_OP_AUIPC: begin
        reg_wen_id  = 1;
        operand1_id = instr_addr_if_id;
        operand2_id = imm_u;
      end
      RV32I_OP_I: begin
        unique case (funct3)
          RV32I_ADDI, RV32I_SLTI, RV32I_SLTIU, RV32I_XORI, RV32I_ORI, RV32I_ANDI: begin
            operand1_id = reg1_rdata;
            operand2_id = imm_i;
            reg_wen_id  = 1;
          end
          RV32I_SLLI, RV32I_SRLI_SRAI: begin
            operand1_id = reg1_rdata;
            operand2_id = {27'b0, shamt};
            reg_wen_id  = 1;
          end
        endcase
      end
      RV32I_OP_R: begin
        unique case (funct3)
          RV32I_ADD_SUB, RV32I_SLT, RV32I_SLTU, RV32I_XOR, RV32I_OR, RV32I_AND, RV32I_SLL,
              RV32I_SRL_SRA: begin
            operand1_id = reg1_rdata;
            operand2_id = reg2_rdata;
            reg_wen_id  = 1;
          end
        endcase
      end
    endcase
  end

endmodule
