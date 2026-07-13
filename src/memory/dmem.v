`timescale 1ns / 1ps
`include "memory_internal.vh"

module dmem #(
    parameter PHYS_ADDR_WIDTH = 12,
    parameter MEM_LATENCY = 1,
    parameter INIT_FILE = ""
) (
    input wire clk,
    input wire rst_n,
    input wire dmem_cs,
    input wire [31:0] dmem_addr,
    input wire dmem_we,
    input wire [31:0] dmem_wdata,
    input wire [1:0] dmem_width,
    output wire dmem_ack,
    output wire [31:0] dmem_rdata,
    output wire dmem_fault,
    output wire dmem_irq
);
    localparam WIDTH_WORD = 2'b00;
    localparam WIDTH_HALF = 2'b01;
    localparam WIDTH_BYTE = 2'b10;

    wire word_aligned = (dmem_addr[1:0] == 2'b00);
    wire half_aligned = (dmem_addr[0] == 1'b0);
    wire align_ok =
        (dmem_width == WIDTH_WORD && word_aligned) ||
        (dmem_width == WIDTH_HALF && half_aligned) ||
        (dmem_width == WIDTH_BYTE);
    wire width_ok = (dmem_width != 2'b11);
    wire req_fault = dmem_cs && (!width_ok || !align_ok);

    reg [3:0] backend_wstrb;
    reg [31:0] backend_wdata;

    always @(*) begin
        backend_wstrb = 4'b0000;
        backend_wdata = 32'b0;
        case (dmem_width)
            WIDTH_WORD: begin
                backend_wstrb = 4'b1111;
                backend_wdata = dmem_wdata;
            end
            WIDTH_HALF: begin
                if (dmem_addr[1] == 1'b0) begin
                    backend_wstrb = 4'b0011;
                    backend_wdata = {16'b0, dmem_wdata[15:0]};
                end else begin
                    backend_wstrb = 4'b1100;
                    backend_wdata = {dmem_wdata[15:0], 16'b0};
                end
            end
            WIDTH_BYTE: begin
                case (dmem_addr[1:0])
                    2'b00: begin
                        backend_wstrb = 4'b0001;
                        backend_wdata = {24'b0, dmem_wdata[7:0]};
                    end
                    2'b01: begin
                        backend_wstrb = 4'b0010;
                        backend_wdata = {16'b0, dmem_wdata[7:0], 8'b0};
                    end
                    2'b10: begin
                        backend_wstrb = 4'b0100;
                        backend_wdata = {8'b0, dmem_wdata[7:0], 16'b0};
                    end
                    default: begin
                        backend_wstrb = 4'b1000;
                        backend_wdata = {dmem_wdata[7:0], 24'b0};
                    end
                endcase
            end
            default: begin
                backend_wstrb = 4'b0000;
                backend_wdata = 32'b0;
            end
        endcase
    end

    wire backend_ack;
    wire [31:0] backend_rdata;
    wire backend_fault;

    memory_backend_core #(
        .ADDR_WIDTH(PHYS_ADDR_WIDTH),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE(INIT_FILE)
    ) u_backend (
        .clk(clk),
        .rst_n(rst_n),
        .req(dmem_cs && !req_fault),
        .we(dmem_we),
        .addr(dmem_addr),
        .wdata(backend_wdata),
        .wstrb(backend_wstrb),
        .ack(backend_ack),
        .rdata(backend_rdata),
        .fault(backend_fault)
    );

    assign dmem_ack = req_fault ? dmem_cs : backend_ack;
    assign dmem_rdata = backend_rdata;
    assign dmem_fault = req_fault ? 1'b1 : backend_fault;
    assign dmem_irq = 1'b0;
endmodule
