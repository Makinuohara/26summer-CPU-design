`timescale 1ns / 1ps

module pipeline_control_unit (
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
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
    output reg jalr
);
    localparam OPCODE_OP     = 7'b0110011;
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;

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

    localparam WB_ALU = 2'd0;
    localparam WB_MEM = 2'd1;
    localparam WB_PC4 = 2'd2;
    localparam WB_IMM = 2'd3;

    localparam BR_NONE = 3'd0;
    localparam BR_BEQ  = 3'd1;
    localparam BR_BNE  = 3'd2;
    localparam BR_BLT  = 3'd3;
    localparam BR_BGE  = 3'd4;
    localparam BR_BLTU = 3'd5;
    localparam BR_BGEU = 3'd6;

    wire funct7_base = (funct7 == 7'b0000000);
    wire funct7_alt = (funct7 == 7'b0100000);

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

        case (opcode)
            OPCODE_OP: begin
                reg_write = 1'b1;
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
            OPCODE_OP_IMM: begin
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
                reg_write = 1'b1;
                mem_read = 1'b1;
                alu_src_imm = 1'b1;
                alu_ctrl = ALU_ADD;
                wb_sel = WB_MEM;
                mem_width = 2'b00;
            end
            OPCODE_STORE: begin
                mem_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_ctrl = ALU_ADD;
                mem_width = 2'b00;
            end
            OPCODE_BRANCH: begin
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
                reg_write = 1'b1;
                wb_sel = WB_IMM;
            end
            OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_src_pc = 1'b1;
                alu_ctrl = ALU_ADD;
            end
            default: begin
            end
        endcase
    end
endmodule
