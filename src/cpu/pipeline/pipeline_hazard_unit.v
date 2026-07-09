`timescale 1ns / 1ps

module pipeline_hazard_unit (
    input wire if_id_valid,
    input wire id_ex_valid,
    input wire id_ex_mem_read,
    input wire [4:0] id_ex_rd,
    input wire [4:0] if_id_rs1,
    input wire [4:0] if_id_rs2,
    input wire [6:0] if_id_opcode,
    output wire load_use_stall
);
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_JALR   = 7'b1100111;

    wire instr_uses_rs2 =
        (if_id_opcode != OPCODE_OP_IMM) &&
        (if_id_opcode != OPCODE_LOAD) &&
        (if_id_opcode != OPCODE_JALR);

    assign load_use_stall =
        if_id_valid && id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'd0) &&
        ((id_ex_rd == if_id_rs1) || (instr_uses_rs2 && (id_ex_rd == if_id_rs2)));
endmodule
