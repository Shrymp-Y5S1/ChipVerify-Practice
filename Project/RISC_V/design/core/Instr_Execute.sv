module Instr_Execute
  import RV32I_Inst_Pkg::*;
(
    // input from ID/EX
    input [31:0] instr_id_ex,
    input [31:0] instr_addr_ex,
    input [31:0] operand1_ex,
    input [31:0] operand2_ex,
    input        reg_wen_ex,

    input [31:0] next_pc,

    input        ram_load_access_ex,
    input        ram_store_access_ex,
    input [31:0] ram_load_addr_ex,
    input [31:0] ram_store_addr_ex,
    input [31:0] ram_store_data_ex,


    // output to register
    output logic [31:0] reg_wdata,
    output logic [ 4:0] reg_waddr,
    output logic        reg_wen,

    // memory access
    input        [31:0] ram_load_data,
    output              ram_load_en,
    output              ram_store_en,
    output logic [31:0] ram_load_addr,
    output logic [31:0] ram_store_addr,
    output logic [31:0] ram_store_data,
    output logic [ 1:0] ram_store_width,

    output logic [31:0] jump_addr_ex,
    output logic        jump_en_ex
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
  wire  [31:0] alu_base_addr_offset = instr_addr_ex + imm_b;

  wire         alu_less_signed = $signed(operand1_ex) < $signed(operand2_ex);
  wire         alu_less_unsigned = operand1_ex < operand2_ex;
  wire         alu_equal = operand1_ex == operand2_ex;

  logic        extension_bit;
  always_comb begin
    unique case (funct3)
      RV32I_LB: extension_bit = ram_load_data[7];
      RV32I_LH: extension_bit = ram_load_data[15];
      default:  extension_bit = 0;
    endcase
  end
  wire [31:0] extension_byte = {{24{extension_bit}}, ram_load_data[7:0]};
  wire [31:0] extension_halfword = {{16{extension_bit}}, ram_load_data[15:0]};

  always_comb begin
    reg_wen         = reg_wen_ex;
    reg_waddr       = rd;
    reg_wdata       = 32'b0;
    add_sub         = 1'b1;  // default to add

    ram_load_en     = ram_load_access_ex;
    ram_store_en    = ram_store_access_ex;
    ram_load_addr   = ram_load_addr_ex;
    ram_store_addr  = ram_store_addr_ex;
    ram_store_data  = ram_store_data_ex;
    ram_store_width = funct3[1:0];

    unique case (opcode)
      RV32I_OP_LUI:   reg_wdata = alu_add;  // alu_add=0+imm_u
      RV32I_OP_AUIPC: reg_wdata = alu_add;  // alu_add=PC+imm_u
      RV32I_OP_JAL, RV32I_OP_JALR: begin
        reg_wdata    = next_pc;
        jump_addr_ex = {alu_add[31:0], 1'b0};
        jump_en_ex   = 1'b1;
      end
      RV32I_OP_B: begin
        jump_addr_ex = alu_base_addr_offset;
        unique case (funct3)
          RV32I_BEQ:  jump_en_ex = alu_equal;
          RV32I_BNE:  jump_en_ex = ~alu_equal;
          RV32I_BLT:  jump_en_ex = alu_less_signed;
          RV32I_BGE:  jump_en_ex = ~alu_less_signed;
          RV32I_BLTU: jump_en_ex = alu_less_unsigned;
          RV32I_BGEU: jump_en_ex = ~alu_less_unsigned;
          default:    jump_en_ex = 1'b0;
        endcase
      end
      RV32I_OP_L: begin
        unique case (funct3)
          RV32I_LB, RV32I_LBU: reg_wdata = extension_byte;
          RV32I_LH, RV32I_LHU: reg_wdata = extension_halfword;
          RV32I_LW: reg_wdata = ram_load_data;
          default: ;
        endcase
      end
      RV32I_OP_S: ;  // 已经在译码阶段完成处理
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
