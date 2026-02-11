module CoreReg (
    input clk,
    input rst_sync,
    input stall_n,   // 0: stall, 1: work

    // read
    input        [ 4:0] reg1_raddr,
    input        [ 4:0] reg2_raddr,
    output logic [31:0] reg1_rdata,
    output logic [31:0] reg2_rdata,

    // write
    input [ 4:0] reg_waddr,
    input [31:0] reg_wdata,
    input        reg_wen
);

  logic [31:0] core_reg[31:0];

  always_comb begin
    if (!reg1_raddr) begin
      reg1_rdata = 0;
    end else if (reg_wen && (reg1_raddr == reg_waddr)) begin
      reg_wdata = reg1_rdata;
    end else begin
      reg1_rdata = core_reg[reg1_raddr];
    end
  end

  always_comb begin
    if (!reg2_raddr) begin
      reg2_rdata = 0;
    end else if (reg_wen && (reg2_raddr == reg_waddr)) begin
      reg_wdata = reg2_rdata;
    end else begin
      reg2_rdata = core_reg[reg2_raddr];
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_sync) begin
      if (stall_n && reg_wen && reg_waddr) begin
        core_reg[reg_waddr] <= reg_wdata;
      end
    end
  end

endmodule
