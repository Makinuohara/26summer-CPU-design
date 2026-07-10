`timescale 1ns / 1ps

module tb_pipeline_irq_demo;
    reg clk;
    reg rst_n;
    reg [15:0] sw;

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
    wire sw_ack;
    wire sw_fault;
    wire sw_irq;
    wire [31:0] led_rdata;
    wire led_ack;
    wire led_fault;
    wire [31:0] seg_rdata;
    wire seg_ack;
    wire seg_fault;
    wire [31:0] btn_rdata;
    wire btn_ack;
    wire btn_fault;
    wire btn_irq;
    wire intc_ack;
    wire [31:0] intc_rdata;
    wire intc_fault;
    wire intc_irq;
    wire meip;

    wire [15:0] led;
    wire [6:0] seg;
    wire [7:0] an;
    wire dp;
    wire [7:0] seg_debug_value;
    reg saw_ee;

    pipeline_cpu_top dut (
        .clk(clk),
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
        .debug_pc(),
        .debug_cycle(),
        .debug_instret(),
        .debug_stall(),
        .debug_flush(),
        .debug_x5()
    );

    fpga_demo_imem u_imem (
        .clk(clk),
        .rst_n(rst_n),
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
        .PHYS_ADDR_WIDTH(8),
        .CACHE_LINES(8),
        .LINE_WORDS(4),
        .MEM_LATENCY(2)
    ) u_dmem (
        .clk(clk),
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

    io_switches u_switches (
        .clk(clk),
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
        .clk(clk),
        .rst_n(rst_n),
        .dmem_cs(led_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(led_ack),
        .dmem_rdata(led_rdata),
        .dmem_fault(led_fault),
        .dmem_irq(),
        .led(led)
    );

    io_seg7 u_seg7 (
        .clk(clk),
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
        .dmem_irq(),
        .seg(seg),
        .an(an),
        .dp(dp),
        .debug_value(seg_debug_value)
    );

    io_buttons u_buttons (
        .clk(clk),
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
        .btn(5'b0)
    );

    interrupt_controller u_intc (
        .clk(clk),
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
        .irq_sources({13'b0, btn_irq, sw_irq, 1'b0}),
        .meip(meip)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        sw = 16'h0000;

        repeat (8) @(posedge clk);
        rst_n = 1'b1;

        repeat (620) @(posedge clk);
        if (seg_debug_value !== 8'h03 || led !== 16'h0000) begin
            $display("FAIL: init state wrong led=%h seg=%h pc=%h mem0=%h mem1=%h mem2=%h",
                     led, seg_debug_value, dut.pc,
                     u_dmem.u_backend.mem[0], u_dmem.u_backend.mem[1], u_dmem.u_backend.mem[2]);
            $finish;
        end

        sw = 16'h0001;
        repeat (720) begin
            @(posedge clk);
        end

        if (seg_debug_value !== 8'h13 || led !== 16'h0011) begin
            $display("FAIL: irq mem demo wrong final led=%h seg=%h meip=%b pc=%h",
                     led, seg_debug_value, meip, dut.pc);
            $finish;
        end

        $display("PASS: irq task-4 demo passed led=%h seg=%h", led, seg_debug_value);
        $finish;
    end
endmodule
