`timescale 1ns / 1ps

module tb_pipeline_io_integration;
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

    reg [31:0] instr_word;

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
        .mem_ack(1'b0),
        .mem_rdata(32'b0),
        .mem_fault(1'b0),
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

    assign imem_ack = imem_req;
    assign imem_data = instr_word;

    always @(*) begin
        case (imem_addr)
            32'h0000_0000: instr_word = 32'h1000_0093; // addi x1, x0, 0x100
            32'h0000_0004: instr_word = 32'h3050_9073; // csrrw x0, mtvec, x1
            32'h0000_0008: instr_word = 32'h8100_0137; // lui x2, 0x81000
            32'h0000_000c: instr_word = 32'h0010_0193; // addi x3, x0, 1
            32'h0000_0010: instr_word = 32'h0031_2223; // sw x3, 4(x2)
            32'h0000_0014: instr_word = 32'h8100_2637; // lui x12, 0x81002
            32'h0000_0018: instr_word = 32'h0020_0193; // addi x3, x0, 2
            32'h0000_001c: instr_word = 32'h0036_2023; // sw x3, 0(x12)
            32'h0000_0020: instr_word = 32'h8120_06b7; // lui x13, 0x81200
            32'h0000_0024: instr_word = 32'h0006_a023; // sw x0, 0(x13)
            32'h0000_0028: instr_word = 32'h0000_11b7; // lui x3, 0x1
            32'h0000_002c: instr_word = 32'h8001_8193; // addi x3, x3, -2048
            32'h0000_0030: instr_word = 32'h3041_a073; // csrrs x0, mie, x3
            32'h0000_0034: instr_word = 32'h0080_0193; // addi x3, x0, 8
            32'h0000_0038: instr_word = 32'h3001_a073; // csrrs x0, mstatus, x3
            32'h0000_003c: instr_word = 32'h8000_0237; // lui x4, 0x80000
            32'h0000_0040: instr_word = 32'h0082_2283; // lw x5, 8(x4)
            32'h0000_0044: instr_word = 32'h0302_2383; // lw x7, 48(x4)
            32'h0000_0048: instr_word = 32'h0000_0013; // nop
            32'h0000_004c: instr_word = 32'h0072_82b3; // add x5, x5, x7
            32'h0000_0050: instr_word = 32'h0052_2623; // sw x5, 12(x4)
            32'h0000_0054: instr_word = 32'h0052_2823; // sw x5, 16(x4)
            32'h0000_0058: instr_word = 32'hff9f_f06f; // jal x0, 0x50
            32'h0000_0100: instr_word = 32'h0046_a503; // lw x10, 4(x13)
            32'h0000_0104: instr_word = 32'h0013_0313; // addi x6, x6, 1
            32'h0000_0108: instr_word = 32'h00a6_a223; // sw x10, 4(x13)
            32'h0000_010c: instr_word = 32'h3020_0073; // mret
            default: instr_word = 32'h0000_0013;
        endcase
    end

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

        repeat (40) @(posedge clk);

        if (led !== 16'h00a5) begin
            $display("FAIL: LED expected 00a5, got %h", led);
            $finish;
        end

        if (seg_debug_value !== 8'ha5) begin
            $display("FAIL: SEG expected a5, got %h", seg_debug_value);
            $finish;
        end

        if (dut.u_regfile.regs[5] !== 32'h0000_00a5) begin
            $display("FAIL: x5 expected 0x000000a5, got %h", dut.u_regfile.regs[5]);
            $finish;
        end

        irq_sources[1] = 1'b1;
        repeat (8) @(posedge clk);
        irq_sources[1] = 1'b0;

        repeat (60) @(posedge clk);

        if (dut.u_regfile.regs[6] !== 32'h0000_0001) begin
            $display("FAIL: x6 expected single interrupt service, got %h", dut.u_regfile.regs[6]);
            $finish;
        end

        if (dut.u_regfile.regs[10] !== 32'h0000_0001) begin
            $display("FAIL: x10 expected claimed interrupt id 1, got %h (x6=%h meip=%b pc=%h claimed=%h pending=%h)",
                     dut.u_regfile.regs[10], dut.u_regfile.regs[6], meip, debug_pc,
                     u_intc.claimed, (irq_sources & ~u_intc.claimed));
            $finish;
        end

        if (meip !== 1'b0) begin
            $display("FAIL: meip expected low after claim/complete, got %b", meip);
            $finish;
        end

        if (debug_flush == 32'b0) begin
            $display("FAIL: expected flush count to increase after trap");
            $finish;
        end

        $display("PASS: CPU-IO integration passed; led=%h seg=%h irq_count=%0d flush=%0d",
                 led, seg_debug_value, dut.u_regfile.regs[6], debug_flush);
        $finish;
    end

endmodule
