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

  wire  [31:0] inst = instr_id_ex;

  // instruction fields
  wire  [ 6:0] opcode = inst[6:0];
  wire  [ 2:0] funct3 = inst[14:12];
  wire  [ 6:0] funct7 = inst[31:25];
  wire  [ 4:0] rs1 = inst[19:15];
  wire  [ 4:0] rs2 = inst[24:20];
  wire  [ 4:0] rd = inst[11:7];

  // immediate values
  wire  [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
  wire  [31:0] imm_u = {inst[31:12], 12'b0};
  wire  [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
  wire  [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
  wire  [31:0] imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

  // execute logic
  logic        add_sub;  // 1 for add, 0 for sub
  wire  [31:0] alu_add = add_sub ? (operand1_ex + operand2_ex) : (operand1_ex - operand2_ex);
  wire  [31:0] alu_xor = operand1_ex ^ operand2_ex;
  wire  [31:0] alu_or = operand1_ex | operand2_ex;
  wire  [31:0] alu_and = operand1_ex & operand2_ex;
  wire  [31:0] alu_shift_left = operand1_ex << operand2_ex[4:0];
  wire  [31:0] alu_shift_right_logic = operand1_ex >> operand2_ex[4:0];
  wire  [31:0] alu_shift_right_arith = $signed(operand1_ex) >>> operand2_ex[4:0];
  wire         alu_less_signed = $signed(operand1_ex) < $signed(operand2_ex);
  wire         alu_less_unsigned = operand1_ex < operand2_ex;

  always_comb begin
    reg_wen   = reg_wen_ex;
    reg_waddr = rd;
    reg_wdata = 32'b0;
    add_sub   = 1'b1;  // default to add

    unique case (opcode)
      RV32I_OP_LUI:   reg_wdata = alu_add;  // alu_add=0+imm_u
      RV32I_OP_AUIPC: reg_wdata = alu_add;  // alu_add=PC+imm_u
      //   RV32I_OP_JAL: begin
      //     reg_wdata = instr_addr_ex + 4;  // rd = PC + 4
      //   end
      RV32I_OP_I: begin
        unique case (funct3)
          RV32I_ADDI:  reg_wdata = alu_add;
          RV32I_SLTI:  reg_wdata = alu_less_signed;
          RV32I_SLTIU: reg_wdata = alu_less_unsigned;
          RV32I_XORI:  reg_wdata = alu_xor;
          RV32I_ORI:   reg_wdata = alu_or;
          RV32I_ANDI:  reg_wdata = alu_and;
          RV32I_SLLI:  reg_wdata = alu_shift_left;
          RV32I_SRLI_SRAI: begin
            if (funct7[5]) begin  // SRAI
              reg_wdata = alu_shift_right_arith;
            end else begin  // SRLI
              reg_wdata = alu_shift_right_logic;
            end
          end
        endcase
      end

      RV32I_OP_R: begin
        unique case (funct3)
          RV32I_ADD_SUB: begin
            if (funct7[5] == 1) begin
              add_sub = 1'b0;  // sub
            end
            reg_wdata = alu_add;
          end
          RV32I_SLT:  reg_wdata = alu_less_signed;
          RV32I_SLTU: reg_wdata = alu_less_unsigned;
          RV32I_XOR:  reg_wdata = alu_xor;
          RV32I_OR:   reg_wdata = alu_or;
          RV32I_AND:  reg_wdata = alu_and;
          RV32I_SLL:  reg_wdata = alu_shift_left;
          RV32I_SRLI_SRAI: begin
            if (funct7[5]) begin  // SRA
              reg_wdata = alu_shift_right_arith;
            end else begin  // SRL
              reg_wdata = alu_shift_right_logic;
            end
          end
        endcase
      end

    endcase
  end

endmodule
