module Instr_Fetch(
        input [31:0] pc,
        input [31:0] instr,
        output logic [31:0] instr_addr,

        output logic [31:0] instr_if,
        output logic [31:0] instr_addr_if
    );

    assign instr_addr_if = pc;
    assign instr_addr = pc;

    assign instr_if = instr;

endmodule
