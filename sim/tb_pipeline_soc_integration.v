`timescale 1ns / 1ps

module tb_pipeline_soc_integration;
    reg clk;
    reg rst_n;

    reg [15:0] sw;
    reg [4:0] btn;
    reg [15:0] irq_sources;

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

    wire [31:0] debug_pc;
    wire [31:0] debug_cycle;
    wire [31:0] debug_instret;
    wire [31:0] debug_stall;
    wire [31:0] debug_flush;
    wire [31:0] debug_x5;

    wire [15:0] led;
    wire [6:0] seg;
    wire [7:0] an;
    wire dp;
    wire [7:0] seg_debug_value;
    wire meip;
    wire intc_irq;

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
        .debug_pc(debug_pc),
        .debug_cycle(debug_cycle),
        .debug_instret(debug_instret),
        .debug_stall(debug_stall),
        .debug_flush(debug_flush),
        .debug_x5(debug_x5)
    );

    imem #(
        .ADDR_WIDTH(9),
        .MEM_LATENCY(2),
        .INIT_FILE("sim/pipeline_soc_integration_imem.hex")
    ) u_imem (
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
        .dmem_ack(),
        .dmem_rdata(sw_rdata),
        .dmem_fault(sw_fault),
        .dmem_irq(),
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
        .dmem_ack(),
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
        .dmem_ack(),
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
        .dmem_ack(),
        .dmem_rdata(btn_rdata),
        .dmem_fault(btn_fault),
        .dmem_irq(),
        .btn(btn)
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
        .irq_sources(irq_sources),
        .meip(meip)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        sw = 16'h00a0;
        btn = 5'h05;
        irq_sources = 16'b0;

        repeat (6) @(posedge clk);
        rst_n = 1'b1;

        repeat (320) @(posedge clk);

        if (u_dmem.u_backend.mem[0] !== 32'h0000_000c) begin
            $display("FAIL: dmem[0] expected 12, got %h", u_dmem.u_backend.mem[0]);
            $finish;
        end

        if (u_dmem.u_backend.mem[1] !== 32'h0000_00b1) begin
            $display("FAIL: dmem[1] expected 0x000000b1, got %h (pc=%h x3=%h x5=%h x7=%h x8=%h x9=%h led=%h seg=%h)",
                     u_dmem.u_backend.mem[1], debug_pc, dut.u_regfile.regs[3], dut.u_regfile.regs[5],
                     dut.u_regfile.regs[7], dut.u_regfile.regs[8], dut.u_regfile.regs[9], led, seg_debug_value);
            $finish;
        end

        if (dut.u_regfile.regs[9] !== 32'h0000_00b1) begin
            $display("FAIL: x9 expected 0x000000b1, got %h", dut.u_regfile.regs[9]);
            $finish;
        end

        if (led !== 16'h00a5) begin
            $display("FAIL: LED expected 00a5, got %h", led);
            $finish;
        end

        if (seg_debug_value !== 8'ha5) begin
            $display("FAIL: SEG expected a5, got %h", seg_debug_value);
            $finish;
        end

        irq_sources[1] = 1'b1;
        wait (dut.u_regfile.regs[6] == 32'h0000_0001);
        repeat (8) @(posedge clk);
        irq_sources[1] = 1'b0;

        repeat (200) @(posedge clk);

        if (dut.u_regfile.regs[6] !== 32'h0000_0001) begin
            $display("FAIL: x6 expected single interrupt service, got %h", dut.u_regfile.regs[6]);
            $finish;
        end

        if (u_dmem.u_backend.mem[2] !== 32'h0000_0001) begin
            $display("FAIL: dmem[2] expected saved irq id 1, got %h", u_dmem.u_backend.mem[2]);
            $finish;
        end

        if (u_dmem.u_backend.mem[3] !== 32'h0000_0010) begin
            $display("FAIL: dmem[3] expected latched interrupt marker 0x10, got %h", u_dmem.u_backend.mem[3]);
            $finish;
        end

        if (led !== 16'h00b5) begin
            $display("FAIL: LED expected 00b5 after interrupt marker, got %h", led);
            $finish;
        end

        if (seg_debug_value !== 8'hb5) begin
            $display("FAIL: SEG expected b5 after interrupt marker, got %h", seg_debug_value);
            $finish;
        end

        if (u_intc.claimed !== 16'b0) begin
            $display("FAIL: interrupt controller claimed bits expected clear, got %h", u_intc.claimed);
            $finish;
        end

        if (meip !== 1'b0) begin
            $display("FAIL: meip expected low after claim/complete, got %b", meip);
            $finish;
        end

        if (debug_stall == 32'b0) begin
            $display("FAIL: expected non-zero stalls from imem/dmem latency");
            $finish;
        end

        if (debug_flush == 32'b0) begin
            $display("FAIL: expected non-zero flush from trap flow");
            $finish;
        end

        $display("PASS: pipeline SoC integration passed; cycle=%0d instret=%0d stall=%0d flush=%0d led=%h seg=%h",
                 debug_cycle, debug_instret, debug_stall, debug_flush, led, seg_debug_value);
        $finish;
    end

endmodule
