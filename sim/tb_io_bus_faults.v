`timescale 1ns / 1ps

module tb_io_bus_faults;
    reg clk;
    reg rst_n;
    reg req;
    reg [31:0] addr;
    reg we;
    reg [31:0] wdata;
    reg [1:0] width;
    reg [15:0] sw;
    reg [4:0] btn;

    wire ack;
    wire [31:0] rdata;
    wire fault;
    wire [15:0] led;
    wire [6:0] seg;
    wire [7:0] an;
    wire dp;
    wire [7:0] debug_seg_value;

    wire mem_cs;
    wire sw_cs;
    wire led_cs;
    wire seg_cs;
    wire btn_cs;
    wire sw_ack;
    wire led_ack;
    wire seg_ack;
    wire btn_ack;
    wire [31:0] sw_rdata;
    wire [31:0] led_rdata;
    wire [31:0] seg_rdata;
    wire [31:0] btn_rdata;
    wire sw_fault;
    wire led_fault;
    wire seg_fault;
    wire btn_fault;

    dmem_bus_decoder u_decoder (
        .dmem_req(req),
        .dmem_addr(addr),
        .dmem_we(we),
        .dmem_wdata(wdata),
        .dmem_width(width),
        .dmem_ack(ack),
        .dmem_rdata(rdata),
        .dmem_fault(fault),
        .mem_cs(mem_cs),
        .mem_ack(1'b0),
        .mem_rdata(32'b0),
        .mem_fault(1'b0),
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
        .btn_fault(btn_fault)
    );

    io_switches u_sw (
        .clk(clk),
        .rst_n(rst_n),
        .dmem_cs(sw_cs),
        .dmem_addr(addr),
        .dmem_we(we),
        .dmem_wdata(wdata),
        .dmem_width(width),
        .dmem_ack(sw_ack),
        .dmem_rdata(sw_rdata),
        .dmem_fault(sw_fault),
        .dmem_irq(),
        .sw(sw)
    );

    io_leds u_led (
        .clk(clk),
        .rst_n(rst_n),
        .dmem_cs(led_cs),
        .dmem_addr(addr),
        .dmem_we(we),
        .dmem_wdata(wdata),
        .dmem_width(width),
        .dmem_ack(led_ack),
        .dmem_rdata(led_rdata),
        .dmem_fault(led_fault),
        .dmem_irq(),
        .led(led)
    );

    io_seg7 u_seg (
        .clk(clk),
        .scan_clk(clk),
        .rst_n(rst_n),
        .dmem_cs(seg_cs),
        .dmem_addr(addr),
        .dmem_we(we),
        .dmem_wdata(wdata),
        .dmem_width(width),
        .dmem_ack(seg_ack),
        .dmem_rdata(seg_rdata),
        .dmem_fault(seg_fault),
        .dmem_irq(),
        .seg(seg),
        .an(an),
        .dp(dp),
        .debug_value(debug_seg_value)
    );

    io_buttons u_btn (
        .clk(clk),
        .rst_n(rst_n),
        .dmem_cs(btn_cs),
        .dmem_addr(addr),
        .dmem_we(we),
        .dmem_wdata(wdata),
        .dmem_width(width),
        .dmem_ack(btn_ack),
        .dmem_rdata(btn_rdata),
        .dmem_fault(btn_fault),
        .dmem_irq(),
        .btn(btn)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task cycle;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task bus_write;
        input [31:0] a;
        input [31:0] d;
        begin
            req = 1'b1;
            addr = a;
            we = 1'b1;
            wdata = d;
            width = 2'b00;
            cycle();
            req = 1'b0;
            we = 1'b0;
        end
    endtask

    task bus_read;
        input [31:0] a;
        begin
            req = 1'b1;
            addr = a;
            we = 1'b0;
            wdata = 32'b0;
            width = 2'b00;
            cycle();
            req = 1'b0;
        end
    endtask

    initial begin
        rst_n = 1'b0;
        req = 1'b0;
        addr = 32'b0;
        we = 1'b0;
        wdata = 32'b0;
        width = 2'b00;
        sw = 16'h00a5;
        btn = 5'b11000;
        cycle();
        rst_n = 1'b1;
        cycle();
        cycle();

        bus_write(32'h80000008, 32'h12345678);
        if (!ack || !fault) begin
            $display("FAIL: writing SW should ack with fault");
            $finish;
        end

        bus_write(32'h80000030, 32'h12345678);
        if (!ack || !fault) begin
            $display("FAIL: writing BTN should ack with fault");
            $finish;
        end

        bus_write(32'h8000000c, 32'h000000fe);
        if (!ack || fault || led !== 16'h00fe) begin
            $display("FAIL: LED write expected 00fe, got led=%h fault=%b", led, fault);
            $finish;
        end

        bus_write(32'h80000010, 32'h000000ff);
        if (!ack || fault || debug_seg_value !== 8'hff) begin
            $display("FAIL: SEG write expected ff, got %h fault=%b", debug_seg_value, fault);
            $finish;
        end

        bus_read(32'h90000000);
        if (!ack || !fault) begin
            $display("FAIL: unmapped address should ack with fault");
            $finish;
        end

        $display("PASS: IO bus faults passed");
        $finish;
    end

    wire unused_outputs = seg[0] ^ an[0] ^ dp ^ rdata[0] ^ mem_cs;
endmodule
