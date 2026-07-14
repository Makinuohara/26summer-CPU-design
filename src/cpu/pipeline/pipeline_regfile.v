`timescale 1ns / 1ps

// RV32 通用寄存器堆。
//
// 提供两个组合读端口和一个同步写端口。
// x0 被硬连为 0，任何对 x0 的写入都会被忽略。
module pipeline_regfile (
    input wire clk,
    input wire rst_n,
    input wire reg_write,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    output wire [31:0] debug_x5
);
    reg [31:0] regs [0:31];
    integer i;

    // 写端口在时钟上升沿提交。
    // 复位时清空所有寄存器，便于仿真和上板观察初始状态。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (reg_write && rd != 5'b0) begin
            regs[rd] <= write_data;
        end
    end

    // 读端口为组合逻辑。
    // 如果同一拍 WB 正在写某个源寄存器，直接旁路 write_data，
    // 避免 ID 阶段读到旧值。
    assign read_data1 = (rs1 == 5'b0) ? 32'b0 :
                        ((reg_write && rd != 5'b0 && rd == rs1) ? write_data : regs[rs1]);
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 :
                        ((reg_write && rd != 5'b0 && rd == rs2) ? write_data : regs[rs2]);
    assign debug_x5 = regs[5];
endmodule
