`timescale 1ns / 1ps

// 流水线冒险检测单元。
//
// 当前只处理最关键的 load-use 数据冒险：
// 前一条 load 的目的寄存器如果被下一条指令立即使用，
// 由于访存数据还未返回，必须插入一个气泡。
module pipeline_hazard_unit (
    input wire if_id_valid,
    input wire id_ex_valid,
    input wire id_ex_mem_read,
    input wire [4:0] id_ex_rd,
    input wire [4:0] if_id_rs1,
    input wire [4:0] if_id_rs2,
    input wire [6:0] if_id_opcode,
    input wire [2:0] if_id_funct3,
    output wire load_use_stall
);
    // 这些 opcode 用于判断 IF/ID 阶段指令是否真的读取 rs1/rs2。
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;
    localparam OPCODE_SYSTEM = 7'b1110011;

    // rs1 使用场景：I 型 ALU、load/store 基址、branch 比较、JALR 基址、
    // 以及非立即数形式的 CSR 指令。
    wire instr_uses_rs1 =
        (if_id_opcode == OPCODE_OP_IMM) ||
        (if_id_opcode == OPCODE_LOAD) ||
        (if_id_opcode == OPCODE_STORE) ||
        (if_id_opcode == OPCODE_BRANCH) ||
        (if_id_opcode == OPCODE_JALR) ||
        ((if_id_opcode == OPCODE_SYSTEM) && (if_id_funct3 != 3'b000) && !if_id_funct3[2]);

    // rs2 只在 store 写数据和 branch 比较中使用。
    wire instr_uses_rs2 =
        (if_id_opcode == OPCODE_STORE) ||
        (if_id_opcode == OPCODE_BRANCH);

    // 如果 ID/EX 是 load，且它的 rd 被 IF/ID 指令作为源寄存器使用，
    // 就要求顶层冻结 PC/IF/ID，并向 ID/EX 插入气泡。
    assign load_use_stall =
        if_id_valid && id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'd0) &&
        ((instr_uses_rs1 && (id_ex_rd == if_id_rs1)) ||
         (instr_uses_rs2 && (id_ex_rd == if_id_rs2)));
endmodule
