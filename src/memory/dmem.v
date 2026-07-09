`timescale 1ns / 1ps
`include "memory_internal.vh"

module dmem #(
    parameter PHYS_ADDR_WIDTH = 12,
    parameter CACHE_LINES = 16,
    parameter LINE_WORDS = 4,
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
    wire cache_req;
    wire cache_we;
    wire [31:0] cache_addr;
    wire [31:0] cache_wdata;
    wire [3:0] cache_wstrb;
    wire cache_mem_ack;
    wire [31:0] cache_mem_rdata;
    wire cache_mem_fault;

    cache #(
        .CACHE_LINES(CACHE_LINES),
        .LINE_WORDS(LINE_WORDS)
    ) u_cache (
        .clk(clk),
        .rst_n(rst_n),
        .req(dmem_cs),
        .addr(dmem_addr),
        .we(dmem_we),
        .wdata(dmem_wdata),
        .width(dmem_width),
        .ack(dmem_ack),
        .rdata(dmem_rdata),
        .fault(dmem_fault),
        .mem_req(cache_req),
        .mem_we(cache_we),
        .mem_addr(cache_addr),
        .mem_wdata(cache_wdata),
        .mem_wstrb(cache_wstrb),
        .mem_ack(cache_mem_ack),
        .mem_rdata(cache_mem_rdata),
        .mem_fault(cache_mem_fault)
    );

    memory_backend_core #(
        .ADDR_WIDTH(PHYS_ADDR_WIDTH),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE(INIT_FILE)
    ) u_backend (
        .clk(clk),
        .rst_n(rst_n),
        .req(cache_req),
        .we(cache_we),
        .addr(cache_addr),
        .wdata(cache_wdata),
        .wstrb(cache_wstrb),
        .ack(cache_mem_ack),
        .rdata(cache_mem_rdata),
        .fault(cache_mem_fault)
    );

    assign dmem_irq = 1'b0;
endmodule
