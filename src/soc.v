`timescale 1ns / 1ps

module soc #(
    parameter CLK_DIV_BITS = 18,
    parameter IMEM_ADDR_WIDTH = 12,
    parameter IMEM_LATENCY = 1,
    parameter IMEM_INIT_FILE = "board_test.mem",
    parameter DMEM_PHYS_ADDR_WIDTH = 12,
    parameter DMEM_CACHE_LINES = 16,
    parameter DMEM_LINE_WORDS = 4,
    parameter DMEM_LATENCY = 1
) (
    input wire clk,
    input wire rst_n,

    input wire [15:0] sw,
    input wire [4:0] btn,
    input wire ps2_clk,
    input wire ps2_data,

    output wire [15:0] led,
    output wire [6:0] seg,
    output wire [7:0] an,
    output wire dp,

    output wire [31:0] debug_pc,
    output wire [31:0] debug_cycle,
    output wire [31:0] debug_instret,
    output wire [31:0] debug_stall,
    output wire [31:0] debug_flush,
    output wire [31:0] debug_x5,
    output wire [7:0] debug_seg_value,
    output wire meip
);
    wire cpu_clk;

    clk_div #(
        .DIV_BITS(CLK_DIV_BITS)
    ) u_clk_div (
        .clk(clk),
        .rst(~rst_n),
        .slow_clk(cpu_clk)
    );

    wire imem_req;
    wire [31:0] imem_addr;
    wire imem_ack;
    wire [31:0] imem_data;

    wire dmem_req;
    wire [31:0] dmem_addr;
    wire dmem_we;
    wire [31:0] dmem_wdata;
    wire [1:0] dmem_width;
    wire dmem_ack;
    wire [31:0] dmem_rdata;
    wire dmem_fault;

    wire mem_cs;
    wire mem_ack;
    wire [31:0] mem_rdata;
    wire mem_fault;
    wire mem_irq;

    wire ps2_cs;
    wire ps2_ack;
    wire [31:0] ps2_rdata;
    wire ps2_fault;
    wire ps2_irq;
    wire sw_cs;
    wire led_cs;
    wire seg_cs;
    wire btn_cs;
    wire intc_cs;

    wire [31:0] sw_rdata;
    wire sw_ack;
    wire sw_fault;
    wire sw_irq;
    wire [31:0] led_rdata;
    wire led_ack;
    wire led_fault;
    wire led_irq;
    wire [31:0] seg_rdata;
    wire seg_ack;
    wire seg_fault;
    wire seg_irq;
    wire [31:0] btn_rdata;
    wire btn_ack;
    wire btn_fault;
    wire btn_irq;

    wire intc_ack;
    wire [31:0] intc_rdata;
    wire intc_fault;
    wire intc_irq;
    wire [15:0] irq_sources = {5'b0, sw_irq, 1'b0, btn_irq, 5'b0, ps2_irq, 2'b0};

    pipeline_cpu_top #(
        .DCACHE_LINES(DMEM_CACHE_LINES),
        .DCACHE_LINE_WORDS(DMEM_LINE_WORDS)
    ) u_cpu (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ack(imem_ack),
        .imem_data(imem_data),
        .dmem_req(dmem_req),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(dmem_ack),
        .dmem_rdata(dmem_rdata),
        .dmem_fault(dmem_fault),
        .meip(meip),
        .mtip(1'b0),
        .msip(1'b0),
        .debug_pc(debug_pc),
        .debug_cycle(debug_cycle),
        .debug_instret(debug_instret),
        .debug_stall(debug_stall),
        .debug_flush(debug_flush),
        .debug_x5(debug_x5)
    );

    imem #(
        .ADDR_WIDTH(IMEM_ADDR_WIDTH),
        .MEM_LATENCY(IMEM_LATENCY),
        .INIT_FILE(IMEM_INIT_FILE)
    ) u_imem (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ack(imem_ack),
        .imem_data(imem_data)
    );

    dmem_bus_decoder u_decoder (
        .dmem_req(dmem_req),
        .dmem_addr(dmem_addr),
        .dmem_ack(dmem_ack),
        .dmem_rdata(dmem_rdata),
        .dmem_fault(dmem_fault),
        .mem_cs(mem_cs),
        .mem_ack(mem_ack),
        .mem_rdata(mem_rdata),
        .mem_fault(mem_fault),
        .ps2_cs(ps2_cs),
        .ps2_ack(ps2_ack),
        .ps2_rdata(ps2_rdata),
        .ps2_fault(ps2_fault),
        .sw_cs(sw_cs),
        .sw_ack(sw_ack),
        .sw_rdata(sw_rdata),
        .sw_fault(sw_fault),
        .led_cs(led_cs),
        .led_ack(led_ack),
        .led_rdata(led_rdata),
        .led_fault(led_fault),
        .seg_cs(seg_cs),
        .seg_ack(seg_ack),
        .seg_rdata(seg_rdata),
        .seg_fault(seg_fault),
        .btn_cs(btn_cs),
        .btn_ack(btn_ack),
        .btn_rdata(btn_rdata),
        .btn_fault(btn_fault),
        .intc_cs(intc_cs),
        .intc_ack(intc_ack),
        .intc_rdata(intc_rdata),
        .intc_fault(intc_fault)
    );

    dmem #(
        .PHYS_ADDR_WIDTH(DMEM_PHYS_ADDR_WIDTH),
        .MEM_LATENCY(DMEM_LATENCY)
    ) u_dmem (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .dmem_cs(mem_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(mem_ack),
        .dmem_rdata(mem_rdata),
        .dmem_fault(mem_fault),
        .dmem_irq(mem_irq)
    );

    io_ps2 u_ps2 (
        .clk(cpu_clk),
        .clk_fast(clk),
        .rst_n(rst_n),
        .dmem_cs(ps2_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(ps2_ack),
        .dmem_rdata(ps2_rdata),
        .dmem_fault(ps2_fault),
        .dmem_irq(ps2_irq),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data)
    );

    io_switches u_switches (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .dmem_cs(sw_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(sw_ack),
        .dmem_rdata(sw_rdata),
        .dmem_fault(sw_fault),
        .dmem_irq(sw_irq),
        .sw(sw)
    );

    io_leds u_leds (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .dmem_cs(led_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(led_ack),
        .dmem_rdata(led_rdata),
        .dmem_fault(led_fault),
        .dmem_irq(led_irq),
        .led(led)
    );

    io_seg7 u_seg7 (
        .clk(cpu_clk),
        .scan_clk(clk),
        .rst_n(rst_n),
        .dmem_cs(seg_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(seg_ack),
        .dmem_rdata(seg_rdata),
        .dmem_fault(seg_fault),
        .dmem_irq(seg_irq),
        .seg(seg),
        .an(an),
        .dp(dp),
        .debug_value(debug_seg_value)
    );

    io_buttons u_buttons (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .dmem_cs(btn_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(btn_ack),
        .dmem_rdata(btn_rdata),
        .dmem_fault(btn_fault),
        .dmem_irq(btn_irq),
        .btn(btn)
    );

    interrupt_controller u_intc (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .dmem_cs(intc_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(intc_ack),
        .dmem_rdata(intc_rdata),
        .dmem_fault(intc_fault),
        .dmem_irq(intc_irq),
        .irq_sources(irq_sources),
        .meip(meip)
    );

    wire unused_irq = mem_irq | led_irq | seg_irq | intc_irq;

endmodule
