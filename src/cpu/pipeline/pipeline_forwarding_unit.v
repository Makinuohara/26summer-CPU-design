`timescale 1ns / 1ps

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
    assign fwd_rs1 =
        (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) ? ex_mem_write_data :
        (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) ? mem_wb_write_data :
        id_ex_rs1_data;

    assign fwd_rs2 =
        (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) ? ex_mem_write_data :
        (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) ? mem_wb_write_data :
        id_ex_rs2_data;
endmodule
