`timescale 1ns / 1ps

module fpga_top (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    input wire [1:0] SW, 
    output wire [15:0] LED,
    output wire [6:0] SEG,
    output wire [7:0] AN,
    output wire DP
);
    wire rst = ~CPU_RESETN;
    wire cpu_clk;
    wire scan_clk;

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
    wire sw_cs;
    wire led_cs;
    wire seg_cs;
    wire btn_cs;
    wire intc_cs;

    wire [31:0] sw_rdata;
    wire sw_fault;
    wire [31:0] led_rdata;
    wire led_fault;
    wire [31:0] seg_rdata;
    wire seg_fault;
    wire [31:0] btn_rdata;
    wire btn_fault;
    wire intc_ack;
    wire [31:0] intc_rdata;
    wire intc_fault;
    wire intc_irq;
    wire meip;

    wire [31:0] debug_pc;
    wire [31:0] debug_cycle;
    wire [31:0] debug_instret;
    wire [31:0] debug_stall;
    wire [31:0] debug_flush;
    wire [31:0] debug_x5;
    wire [15:0] board_sw = {14'b0, SW};
    wire [4:0] board_btn = 5'b0;
    reg sw1_meta;
    reg sw1_sync;
    reg sw1_prev;
    reg sw1_ip;
    wire sw1_irq_pulse = sw1_sync & ~sw1_prev;
    wire [15:0] irq_sources = {14'b0, sw1_irq_pulse, 1'b0};

    always @(posedge cpu_clk or posedge rst) begin
        if (rst) begin
            sw1_meta <= 1'b0;
            sw1_sync <= 1'b0;
            sw1_prev <= 1'b0;
        end else begin
            sw1_meta <= SW[1];
            sw1_sync <= sw1_meta;
            sw1_prev <= sw1_sync;
            sw1_ip <= sw1_ip|(sw1_sync & ~sw1_prev);

        end
    end
    
    clk_div #(
        .DIV_BITS(18)
    ) u_cpu_clk_div (
        .clk(CLK100MHZ),
        .rst(rst),
        .slow_clk(cpu_clk)
    );

    clk_div #(
        .DIV_BITS(15)
    ) u_scan_clk_div (
        .clk(CLK100MHZ),
        .rst(rst),
        .slow_clk(scan_clk)
    );

    pipeline_cpu_top u_cpu (
        .clk(cpu_clk),
        .rst_n(~rst),
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

    fpga_demo_imem u_imem (
        .clk(cpu_clk),
        .rst_n(~rst),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ack(imem_ack),
        .imem_data(imem_data)
    );

    dmem_bus_decoder u_decoder (
        .dmem_req(dmem_req),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata), 
        .dmem_width(dmem_width), 
        .dmem_ack(dmem_ack),
        .dmem_rdata(dmem_rdata),
        .dmem_fault(dmem_fault),
        .mem_cs(mem_cs),
        .mem_ack(mem_ack),
        .mem_rdata(mem_rdata),
        .mem_fault(mem_fault),
        .ps2_cs(ps2_cs),
        .ps2_ack(1'b0),
        .ps2_rdata(32'b0),
        .ps2_fault(1'b0),
        .sw_cs(sw_cs),
        .sw_ack(sw_cs),
        .sw_rdata(sw_rdata),
        .sw_fault(sw_fault),
        .led_cs(led_cs),
        .led_ack(led_cs),
        .led_rdata(led_rdata),
        .led_fault(led_fault),
        .seg_cs(seg_cs),
        .seg_ack(seg_cs),
        .seg_rdata(seg_rdata),
        .seg_fault(seg_fault),
        .btn_cs(btn_cs),
        .btn_ack(btn_cs),
        .btn_rdata(btn_rdata),
        .btn_fault(btn_fault),
        .intc_cs(intc_cs),
        .intc_ack(intc_ack),
        .intc_rdata(intc_rdata),
        .intc_fault(intc_fault)
    );

    dmem #(
        .PHYS_ADDR_WIDTH(8),
        .CACHE_LINES(8),
        .LINE_WORDS(4),
        .MEM_LATENCY(2)
    ) u_dmem (
        .clk(cpu_clk),
        .rst_n(~rst),
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

    io_switches u_switches (
        .clk(cpu_clk),
        .rst_n(~rst),
        .dmem_cs(sw_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(),
        .dmem_rdata(sw_rdata),
        .dmem_fault(sw_fault),
        .dmem_irq(),
        .sw(board_sw)
    );

    io_leds u_leds (
        .clk(cpu_clk),
        .rst_n(~rst),
        .dmem_cs(led_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(),
        .dmem_rdata(led_rdata),
        .dmem_fault(led_fault),
        .dmem_irq(),
        .led(LED)
    );

    io_seg7 u_seg7 (
        .clk(cpu_clk),
        .scan_clk(scan_clk),
        .rst_n(~rst),
        .dmem_cs(seg_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(),
        .dmem_rdata(seg_rdata),
        .dmem_fault(seg_fault),
        .dmem_irq(),
        .seg(SEG),
        .an(AN),
        .dp(DP),
        .debug_value()
    );

    io_buttons u_buttons (
        .clk(cpu_clk),
        .rst_n(~rst),
        .dmem_cs(btn_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(),
        .dmem_rdata(btn_rdata),
        .dmem_fault(btn_fault),
        .dmem_irq(),
        .btn(board_btn)
    );

    interrupt_controller u_intc (
        .clk(cpu_clk),
        .rst_n(~rst),
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

    wire unused_debug = ^{ps2_cs, mem_irq, intc_irq, debug_pc[0], debug_cycle[0], debug_instret[0], debug_stall[0], debug_flush[0], debug_x5[0]};
endmodule
