`timescale 1ns / 1ps

module pipeline_csr_unit (
    input wire clk,
    input wire rst_n,

    input wire [11:0] read_addr,
    output reg [31:0] read_data,

    input wire wb_valid,
    input wire wb_csr_en,
    input wire [1:0] wb_csr_op,
    input wire [11:0] wb_csr_addr,
    input wire [31:0] wb_csr_wdata,

    input wire trap_take,
    input wire [31:0] trap_pc,
    input wire [31:0] trap_cause,
    input wire mret_take,

    input wire meip,
    input wire mtip,
    input wire msip,

    output wire [31:0] mtvec_value,
    output wire [31:0] mepc_value,
    output wire irq_pending,
    output wire [31:0] irq_cause
);
    localparam CSR_MSTATUS = 12'h300;
    localparam CSR_MIE     = 12'h304;
    localparam CSR_MTVEC   = 12'h305;
    localparam CSR_MEPC    = 12'h341;
    localparam CSR_MCAUSE  = 12'h342;
    localparam CSR_MIP     = 12'h344;

    localparam CSR_OP_NONE  = 2'b00;
    localparam CSR_OP_WRITE = 2'b01;
    localparam CSR_OP_SET   = 2'b10;
    localparam CSR_OP_CLEAR = 2'b11;

    reg [31:0] mstatus_reg;
    reg [31:0] mie_reg;
    reg [31:0] mtvec_reg;
    reg [31:0] mepc_reg;
    reg [31:0] mcause_reg;

    reg [31:0] next_mstatus;
    reg [31:0] next_mie;
    reg [31:0] next_mtvec;
    reg [31:0] next_mepc;
    reg [31:0] next_mcause;

    wire [31:0] mip_value = {20'b0, meip, 3'b0, mtip, 3'b0, msip, 3'b0};
    wire mstatus_mie = mstatus_reg[3];
    wire irq_meip = meip && mie_reg[11];
    wire irq_mtip = mtip && mie_reg[7];
    wire irq_msip = msip && mie_reg[3];

    function [31:0] csr_apply_op;
        input [31:0] old_value;
        input [31:0] write_value;
        input [1:0] op;
        begin
            case (op)
                CSR_OP_WRITE: csr_apply_op = write_value;
                CSR_OP_SET: csr_apply_op = old_value | write_value;
                CSR_OP_CLEAR: csr_apply_op = old_value & ~write_value;
                default: csr_apply_op = old_value;
            endcase
        end
    endfunction

    always @(*) begin
        next_mstatus = mstatus_reg;
        next_mie = mie_reg;
        next_mtvec = mtvec_reg;
        next_mepc = mepc_reg;
        next_mcause = mcause_reg;

        if (wb_valid && wb_csr_en && (wb_csr_op != CSR_OP_NONE)) begin
            case (wb_csr_addr)
                CSR_MSTATUS: next_mstatus = csr_apply_op(mstatus_reg, wb_csr_wdata, wb_csr_op);
                CSR_MIE: next_mie = csr_apply_op(mie_reg, wb_csr_wdata, wb_csr_op);
                CSR_MTVEC: next_mtvec = csr_apply_op(mtvec_reg, wb_csr_wdata, wb_csr_op) & 32'hffff_fffc;
                CSR_MEPC: next_mepc = csr_apply_op(mepc_reg, wb_csr_wdata, wb_csr_op) & 32'hffff_fffe;
                CSR_MCAUSE: next_mcause = csr_apply_op(mcause_reg, wb_csr_wdata, wb_csr_op);
                default: begin
                end
            endcase
        end

        if (trap_take) begin
            next_mepc = trap_pc & 32'hffff_fffe;
            next_mcause = trap_cause;
            next_mstatus[7] = next_mstatus[3];
            next_mstatus[3] = 1'b0;
        end else if (mret_take) begin
            next_mstatus[3] = next_mstatus[7];
            next_mstatus[7] = 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus_reg <= 32'h0000_0000;
            mie_reg <= 32'h0000_0000;
            mtvec_reg <= 32'h0000_0000;
            mepc_reg <= 32'h0000_0000;
            mcause_reg <= 32'h0000_0000;
        end else begin
            mstatus_reg <= next_mstatus;
            mie_reg <= next_mie;
            mtvec_reg <= next_mtvec;
            mepc_reg <= next_mepc;
            mcause_reg <= next_mcause;
        end
    end

    always @(*) begin
        case (read_addr)
            CSR_MSTATUS: read_data = mstatus_reg;
            CSR_MIE: read_data = mie_reg;
            CSR_MTVEC: read_data = mtvec_reg;
            CSR_MEPC: read_data = mepc_reg;
            CSR_MCAUSE: read_data = mcause_reg;
            CSR_MIP: read_data = mip_value;
            default: read_data = 32'b0;
        endcase
    end

    assign mtvec_value = mtvec_reg;
    assign mepc_value = mepc_reg;
    assign irq_pending = mstatus_mie && (irq_meip || irq_mtip || irq_msip);
    assign irq_cause =
        irq_meip ? 32'h8000_000b :
        irq_mtip ? 32'h8000_0007 :
        irq_msip ? 32'h8000_0003 :
                   32'h0000_0000;

endmodule
