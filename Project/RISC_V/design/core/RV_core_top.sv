module RV_core_top (
    input clk,
    input rst_sync,

    input        [31:0] instr,
    output logic [31:0] instr_addr
);

  // output declaration of module CoreCtrl
  wire [31:0] jump_addr;
  wire        jump;
  wire        stall_n;
  wire        flush;
  // output declaration of module PC_Reg
  wire [31:0] pc;
  // output declaration of module Instr_Fetch
  wire [31:0] instr_addr;
  wire [31:0] instr_if;
  wire [31:0] instr_addr_if;
  // output declaration of module IF_ID
  wire [31:0] instr_if_id;
  wire [31:0] instr_addr_if_id;
  // output declaration of module Instr_Decoder
  wire [ 4:0] reg1_raddr;
  wire [ 4:0] reg2_raddr;
  wire [31:0] instr_addr_id;
  wire [31:0] instr_id;
  wire [31:0] operand1_id;
  wire [31:0] operand2_id;
  wire        reg_wen_id;
  // output declaration of module CoreReg
  wire [31:0] reg1_rdata;
  wire [31:0] reg2_rdata;
  // output declaration of module ID_EX
  wire [31:0] instr_addr_ex;
  wire [31:0] instr_id_ex;
  wire [31:0] operand1_ex;
  wire [31:0] operand2_ex;
  wire        reg_wen_ex;
  // output declaration of module Instr_Execute
  wire [31:0] reg_wdata;
  wire [ 4:0] reg_waddr;
  wire        reg_wen;

  CoreCtrl u_CoreCtrl (
      .clk      (clk),
      .rst_sync (rst_sync),
      .jump_addr(jump_addr),
      .jump     (jump),
      .stall_n  (stall_n),
      .flush    (flush)
  );


  PC_Reg u_PC_Reg (
      .clk      (clk),
      .rst_sync (rst_sync),
      .stall_n  (stall_n),
      .jump_addr(jump_addr),
      .jump_en  (jump_en),
      .pc       (pc)
  );


  Instr_Fetch u_Instr_Fetch (
      .pc           (pc),
      .instr        (instr),
      .instr_addr   (instr_addr),
      .instr_if     (instr_if),
      .instr_addr_if(instr_addr_if)
  );


  IF_ID u_IF_ID (
      .clk             (clk),
      .rst_sync        (rst_sync),
      .stall_n         (stall_n),
      .flush           (flush),
      .instr_if        (instr_if),
      .instr_addr_if   (instr_addr_if),
      .instr_if_id     (instr_if_id),
      .instr_addr_if_id(instr_addr_if_id)
  );


  Instr_Decoder u_Instr_Decoder (
      .instr_if_id     (instr_if_id),
      .instr_addr_if_id(instr_addr_if_id),
      .reg1_raddr      (reg1_raddr),
      .reg2_raddr      (reg2_raddr),
      .reg1_rdata      (reg1_rdata),
      .reg2_rdata      (reg2_rdata),
      .instr_addr_id   (instr_addr_id),
      .instr_id        (instr_id),
      .operand1_id     (operand1_id),
      .operand2_id     (operand2_id),
      .reg_wen_id      (reg_wen_id)
  );


  CoreReg u_CoreReg (
      .clk       (clk),
      .rst_sync  (rst_sync),
      .stall_n   (stall_n),
      .reg1_raddr(reg1_raddr),
      .reg2_raddr(reg2_raddr),
      .reg1_rdata(reg1_rdata),
      .reg2_rdata(reg2_rdata),
      .reg_waddr (reg_waddr),
      .reg_wdata (reg_wdata),
      .reg_wen   (reg_wen)
  );



  ID_EX u_ID_EX (
      .clk          (clk),
      .rst_sync     (rst_sync),
      .stall_n      (stall_n),
      .flush        (flush),
      .instr_addr_id(instr_addr_id),
      .instr_id     (instr_id),
      .operand1_id  (operand1_id),
      .operand2_id  (operand2_id),
      .reg_wen_id   (reg_wen_id),
      .instr_addr_ex(instr_addr_ex),
      .instr_id_ex  (instr_id_ex),
      .operand1_ex  (operand1_ex),
      .operand2_ex  (operand2_ex),
      .reg_wen_ex   (reg_wen_ex)
  );


  Instr_Execute u_Instr_Execute (
      .instr_id_ex  (instr_id_ex),
      .instr_addr_ex(instr_addr_ex),
      .operand1_ex  (operand1_ex),
      .operand2_ex  (operand2_ex),
      .reg_wen_ex   (reg_wen_ex),
      .reg_wdata    (reg_wdata),
      .reg_waddr    (reg_waddr),
      .reg_wen      (reg_wen)
  );


endmodule
