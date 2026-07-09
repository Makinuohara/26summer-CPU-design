`timescale 1ns / 1ps
`include "memory_internal.vh"

module imem #(
    parameter ADDR_WIDTH = 12,
    parameter MEM_LATENCY = 1,
    parameter INIT_FILE = ""
) (
    input wire clk,
    input wire rst_n,
    input wire imem_req,
    input wire [31:0] imem_addr,
    output reg imem_ack,
    output reg [31:0] imem_data
);
    wire backend_ack;
    wire [31:0] backend_rdata;
    wire backend_fault;
    wire aligned = (imem_addr[1:0] == 2'b00);

    memory_backend_core #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE(INIT_FILE)
    ) u_backend (
        .clk(clk),
        .rst_n(rst_n),
        .req(imem_req),
        .we(1'b0),
        .addr(imem_addr),
        .wdata(32'b0),
        .wstrb(4'b0000),
        .ack(backend_ack),
        .rdata(backend_rdata),
        .fault(backend_fault)
    );

    always @(*) begin
        imem_ack = backend_ack;
        imem_data = (aligned && !backend_fault) ? backend_rdata : 32'h0000_0013;
    end
endmodule
