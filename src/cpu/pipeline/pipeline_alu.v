`timescale 1ns / 1ps

// 流水线 EX 阶段使用的算术逻辑单元。
//
// 该模块是纯组合逻辑：输入操作数和 alu_ctrl 变化后，
// result 会立即按对应运算重新计算。乘除法扩展也在这里完成。
module pipeline_alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] alu_ctrl,
    output reg [31:0] result
);
    // alu_ctrl 编码需要和 pipeline_control_unit.v 保持一致。
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_AND  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_XOR  = 4'd4;
    localparam ALU_SLL  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_SLT  = 4'd8;
    localparam ALU_SLTU = 4'd9;
    localparam ALU_MUL  = 4'd10;
    localparam ALU_DIV  = 4'd11;

    wire signed [31:0] signed_a = a;
    wire signed [31:0] signed_b = b;

    // 根据译码阶段生成的控制码选择具体运算。
    // 移位指令只使用 b[4:0]，对应 RV32 的 0~31 位移位量。
    always @(*) begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_MUL:  result = signed_a * signed_b;
            ALU_DIV: begin
                // 按 RISC-V M 扩展约定处理除零和最小负数除 -1 的溢出情况。
                if (b == 32'b0) begin
                    result = 32'hffff_ffff;
                end else if (a == 32'h8000_0000 && b == 32'hffff_ffff) begin
                    result = 32'h8000_0000;
                end else begin
                    result = signed_a / signed_b;
                end
            end
            default:  result = 32'b0;
        endcase
    end
endmodule
