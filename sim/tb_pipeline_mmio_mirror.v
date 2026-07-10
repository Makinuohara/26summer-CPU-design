`timescale 1ns / 1ps

module tb_pipeline_mmio_mirror;
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

    wire [15:0] led;
    wire [6:0] seg;
    wire [7:0] an;
    wire dp;
    wire [7:0] seg_debug_value;

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
        .meip(1'b0),
        .mtip(1'b0),
        .msip(1'b0),
        .debug_pc(),
        .debug_cycle(),
        .debug_instret(),
        .debug_stall(),
        .debug_flush(),
        .debug_x5()
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
        .intc_ack(1'b0),
        .intc_rdata(32'b0),
        .intc_fault(1'b0)
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
        .btn(5'b0)
    );

    fpga_demo_imem u_imem (
        .clk(clk),
        .rst_n(rst_n),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ack(imem_ack),
        .imem_data(imem_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            $display("TRACE: t=%0t pc=%h if_id_v=%b if_id_i=%h id_ex_v=%b id_ex_rd=%0d id_ex_mr=%b ex_mem_v=%b ex_mem_rd=%0d ex_mem_mr=%b mem_wb_v=%b mem_wb_rd=%0d mem_wb_rw=%b wb_data=%h x2=%h",
                     $time, dut.pc, dut.if_id_valid, dut.if_id_instr,
                     dut.id_ex_valid, dut.id_ex_rd, dut.id_ex_mem_read,
                     dut.ex_mem_valid, dut.ex_mem_rd, dut.ex_mem_mem_read,
                     dut.mem_wb_valid, dut.mem_wb_rd, dut.mem_wb_reg_write,
                     dut.wb_data, dut.u_regfile.regs[2]);
        end
    end

    initial begin
        rst_n = 1'b0;
        sw = 16'h0000;

        repeat (6) @(posedge clk);
        rst_n = 1'b1;

        repeat (30) @(posedge clk);
        sw = 16'h0003;
        repeat (40) @(posedge clk);
        $display("INFO: after sw=3 led=%h seg=%h dmem_addr=%h dmem_wdata=%h we=%b",
                 led, seg_debug_value, dmem_addr, dmem_wdata, dmem_we);

        if (led !== 16'h0003) begin
            $display("DEBUG: x2=%h rs2_data=%h fwd_rs2=%h ex_mem_store=%h mem_wb_valid=%b mem_wb_rd=%0d wb_data=%h dmem_rdata=%h sw_cs=%b led_cs=%b seg_cs=%b",
                     dut.u_regfile.regs[2], dut.id_ex_rs2_data, dut.fwd_rs2, dut.ex_mem_store_data,
                     dut.mem_wb_valid, dut.mem_wb_rd, dut.wb_data, dmem_rdata, sw_cs, led_cs, seg_cs);
            $display("FAIL: LED expected 0003, got %h", led);
            $finish;
        end

        if (seg_debug_value !== 8'h03) begin
            $display("FAIL: SEG expected 03, got %h", seg_debug_value);
            $finish;
        end

        sw = 16'h0002;
        repeat (60) @(posedge clk);
        $display("INFO: after sw=2 led=%h seg=%h dmem_addr=%h dmem_wdata=%h we=%b",
                 led, seg_debug_value, dmem_addr, dmem_wdata, dmem_we);

        if (led !== 16'h0002) begin
            $display("FAIL: LED expected 0002 after update, got %h", led);
            $finish;
        end

        if (seg_debug_value !== 8'h02) begin
            $display("FAIL: SEG expected 02 after update, got %h", seg_debug_value);
            $finish;
        end

        $display("PASS: MMIO mirror pipeline path passed; led=%h seg=%h", led, seg_debug_value);
        $finish;
    end
endmodule
