`timescale 1ns / 1ps

module pipeline_imm_gen (
    input wire [31:0] instr,
    output reg [31:0] imm
);
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;

    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            OPCODE_OP_IMM,
            OPCODE_LOAD,
            OPCODE_JALR: imm = {{20{instr[31]}}, instr[31:20]};
            OPCODE_STORE: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            OPCODE_BRANCH: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            OPCODE_JAL: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            OPCODE_LUI,
            OPCODE_AUIPC: imm = {instr[31:12], 12'b0};
            default: imm = 32'b0;
        endcase
    end
endmodule
