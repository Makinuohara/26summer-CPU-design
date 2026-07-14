`timescale 1ns / 1ps

// EX 阶段数据前递单元。
//
// 当当前指令的 rs1/rs2 依赖前面尚未写回寄存器堆的结果时，
// 直接从 EX/MEM 或 MEM/WB 阶段取最新值，减少不必要的暂停。
module pipeline_forwarding_unit (
    input wire [4:0] id_ex_rs1,
    input wire [4:0] id_ex_rs2,
    input wire [31:0] id_ex_rs1_data,
    input wire [31:0] id_ex_rs2_data,

    input wire ex_mem_valid,
    input wire ex_mem_reg_write,
    input wire ex_mem_mem_read,
    input wire [4:0] ex_mem_rd,
    input wire [31:0] ex_mem_write_data,

    input wire mem_wb_valid,
    input wire mem_wb_reg_write,
    input wire [4:0] mem_wb_rd,
    input wire [31:0] mem_wb_write_data,

    output wire [31:0] fwd_rs1,
    output wire [31:0] fwd_rs2
);
    // 前递优先级：EX/MEM 比 MEM/WB 更新，所以优先选择 EX/MEM。
    // load 指令在 EX/MEM 阶段数据尚未返回，不能从该阶段前递，
    // 这种情况由 hazard 单元插入 load-use 暂停。
    assign fwd_rs1 =
        (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) ? ex_mem_write_data :
        (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) ? mem_wb_write_data :
        id_ex_rs1_data;

    // rs2 同样用于 ALU 第二操作数，也用于 store 写数据。
    assign fwd_rs2 =
        (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) ? ex_mem_write_data :
        (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) ? mem_wb_write_data :
        id_ex_rs2_data;
endmodule
