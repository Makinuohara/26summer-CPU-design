`timescale 1ns / 1ps

// ID 阶段硬布线控制器。
//
// 根据 RISC-V 指令的 opcode/funct3/funct7 字段生成后续流水级需要的控制信号。
// 本模块不保存状态，是纯组合译码逻辑。
module pipeline_control_unit (
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [31:0] instr,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg [1:0] mem_width,
    output reg alu_src_imm,
    output reg alu_src_pc,
    output reg [3:0] alu_ctrl,
    output reg [1:0] wb_sel,
    output reg [2:0] branch_type,
    output reg jump,
    output reg jalr,
    output reg csr_en,
    output reg [1:0] csr_op,
    output reg csr_use_imm,
    output reg mret
);
    // 主操作码定义。
    localparam OPCODE_OP     = 7'b0110011;
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;
    localparam OPCODE_SYSTEM = 7'b1110011;

    // ALU 控制码，需要和 pipeline_alu.v 保持一致。
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

    // 写回数据来源选择。
    localparam WB_ALU = 2'd0;
    localparam WB_MEM = 2'd1;
    localparam WB_PC4 = 2'd2;
    localparam WB_IMM = 2'd3;

    // 分支类型编码，供 EX 阶段比较逻辑使用。
    localparam BR_NONE = 3'd0;
    localparam BR_BEQ  = 3'd1;
    localparam BR_BNE  = 3'd2;
    localparam BR_BLT  = 3'd3;
    localparam BR_BGE  = 3'd4;
    localparam BR_BLTU = 3'd5;
    localparam BR_BGEU = 3'd6;

    wire funct7_base = (funct7 == 7'b0000000);
    wire funct7_alt = (funct7 == 7'b0100000);
    wire funct7_muldiv = (funct7 == 7'b0000001);

    // 先给所有控制信号设置安全默认值，再按指令类型覆盖。
    // 这样未识别指令默认不会写寄存器、不会访存、不会跳转。
    always @(*) begin
        reg_write = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_width = 2'b00;
        alu_src_imm = 1'b0;
        alu_src_pc = 1'b0;
        alu_ctrl = ALU_ADD;
        wb_sel = WB_ALU;
        branch_type = BR_NONE;
        jump = 1'b0;
        jalr = 1'b0;
        csr_en = 1'b0;
        csr_op = 2'b00;
        csr_use_imm = 1'b0;
        mret = 1'b0;

        case (opcode)
            OPCODE_OP: begin
                // R 型整数运算。funct7=0000001 时作为乘除法扩展处理。
                reg_write = 1'b1;
                if (funct7_muldiv) begin
                    case (funct3)
                        3'b000: alu_ctrl = ALU_MUL;
                        3'b100: alu_ctrl = ALU_DIV;
                        default: begin
                            reg_write = 1'b0;
                            alu_ctrl = ALU_ADD;
                        end
                    endcase
                end else begin
                    case (funct3)
                        3'b000: alu_ctrl = funct7_alt ? ALU_SUB : ALU_ADD;
                        3'b001: alu_ctrl = ALU_SLL;
                        3'b010: alu_ctrl = ALU_SLT;
                        3'b011: alu_ctrl = ALU_SLTU;
                        3'b100: alu_ctrl = ALU_XOR;
                        3'b101: alu_ctrl = funct7_alt ? ALU_SRA : ALU_SRL;
                        3'b110: alu_ctrl = ALU_OR;
                        3'b111: alu_ctrl = ALU_AND;
                        default: alu_ctrl = ALU_ADD;
                    endcase
                end
            end
            OPCODE_OP_IMM: begin
                // I 型 ALU 指令，第二操作数来自立即数。
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;
                    3'b001: alu_ctrl = funct7_base ? ALU_SLL : ALU_SLL;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b101: alu_ctrl = funct7_alt ? ALU_SRA : ALU_SRL;
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end
            OPCODE_LOAD: begin
                // 当前数据通路统一按 32 位 load 使用，宽度字段保留给总线接口。
                reg_write = 1'b1;
                mem_read = 1'b1;
                alu_src_imm = 1'b1;
                alu_ctrl = ALU_ADD;
                wb_sel = WB_MEM;
                mem_width = 2'b00;
            end
            OPCODE_STORE: begin
                // store 不写回寄存器，地址由 rs1 + imm 计算。
                mem_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_ctrl = ALU_ADD;
                mem_width = 2'b00;
            end
            OPCODE_BRANCH: begin
                // 分支是否真正跳转在 EX 阶段结合寄存器值判断。
                case (funct3)
                    3'b000: branch_type = BR_BEQ;
                    3'b001: branch_type = BR_BNE;
                    3'b100: branch_type = BR_BLT;
                    3'b101: branch_type = BR_BGE;
                    3'b110: branch_type = BR_BLTU;
                    3'b111: branch_type = BR_BGEU;
                    default: branch_type = BR_NONE;
                endcase
            end
            OPCODE_JAL: begin
                // JAL/JALR 写回 PC+4，目标地址由顶层流水线逻辑计算。
                reg_write = 1'b1;
                jump = 1'b1;
                wb_sel = WB_PC4;
            end
            OPCODE_JALR: begin
                reg_write = 1'b1;
                jump = 1'b1;
                jalr = 1'b1;
                alu_src_imm = 1'b1;
                wb_sel = WB_PC4;
            end
            OPCODE_LUI: begin
                // LUI 直接把 U 型立即数写回 rd。
                reg_write = 1'b1;
                wb_sel = WB_IMM;
            end
            OPCODE_AUIPC: begin
                // AUIPC 使用 PC + U 型立即数。
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_src_pc = 1'b1;
                alu_ctrl = ALU_ADD;
            end
            OPCODE_SYSTEM: begin
                // 当前支持 MRET 和 CSR 读改写类指令。
                if (instr == 32'h30200073) begin
                    mret = 1'b1;
                end else if (funct3 != 3'b000) begin
                    reg_write = 1'b1;
                    csr_en = 1'b1;
                    csr_op = funct3[1:0];
                    csr_use_imm = funct3[2];
                end
            end
            default: begin
            end
        endcase
    end
endmodule
