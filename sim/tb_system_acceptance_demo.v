`timescale 1ns / 1ps

module tb_system_acceptance_demo;
    reg clk;
    reg rst_n;
    reg [15:0] sw;
    reg [4:0] btn;
    reg ps2_clk;
    reg ps2_data;

    wire [15:0] led;
    wire [6:0] seg;
    wire [7:0] an;
    wire dp;
    wire [31:0] debug_pc;
    wire [31:0] debug_cycle;
    wire [31:0] debug_instret;
    wire [31:0] debug_stall;
    wire [31:0] debug_flush;
    wire meip;

    integer marker_seen;
    reg [31:0] mark_cycle [0:4];
    reg [31:0] mark_instret [0:4];
    reg [31:0] mark_stall [0:4];
    reg [31:0] mark_flush [0:4];

    soc #(
        .CLK_DIV_BITS(1),
        .IMEM_INIT_FILE("sim/system_acceptance_demo.hex"),
        .IMEM_LATENCY(1),
        .DMEM_LATENCY(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sw(sw),
        .btn(btn),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .led(led),
        .seg(seg),
        .an(an),
        .dp(dp),
        .debug_pc(debug_pc),
        .debug_cycle(debug_cycle),
        .debug_instret(debug_instret),
        .debug_stall(debug_stall),
        .debug_flush(debug_flush),
        .debug_x5(),
        .debug_seg_value(),
        .meip(meip)
    );

    function [31:0] displayed_word;
        begin
            displayed_word = {
                dut.u_seg7.raw_digits[7][3:0], dut.u_seg7.raw_digits[6][3:0],
                dut.u_seg7.raw_digits[5][3:0], dut.u_seg7.raw_digits[4][3:0],
                dut.u_seg7.raw_digits[3][3:0], dut.u_seg7.raw_digits[2][3:0],
                dut.u_seg7.raw_digits[1][3:0], dut.u_seg7.raw_digits[0][3:0]
            };
        end
    endfunction

    task wait_display;
        input [31:0] expected;
        input [31:0] max_cycles;
        integer i;
        begin : wait_loop
            for (i = 0; i < max_cycles; i = i + 1) begin
                @(posedge dut.cpu_clk);
                if (displayed_word() === expected)
                    disable wait_loop;
            end
            if (displayed_word() !== expected) begin
                $display("FAIL: display expected=%h actual=%h led=%h pc=%h", expected, displayed_word(), led, debug_pc);
                $finish;
            end
        end
    endtask

    task press_button_and_wait;
        input [4:0] value;
        input [15:0] expected_count;
        reg [31:0] expected_display;
        reg [31:0] count_after_press;
        begin
            expected_display = 32'h88000000 | ({27'b0, value} << 16) | expected_count;
            btn = value;
            wait_display(expected_display, 32'd10000);
            count_after_press = dut.u_dmem.u_backend.mem[16'h086];
            btn = 5'b0;
            repeat (300) @(posedge dut.cpu_clk);
            if (dut.u_dmem.u_backend.mem[16'h086] !== count_after_press) begin
                $display("FAIL: releasing button generated an IRQ, before=%0d after=%0d",
                         count_after_press, dut.u_dmem.u_backend.mem[16'h086]);
                $finish;
            end
        end
    endtask

    task set_switch_and_wait;
        input [15:0] value;
        input [31:0] expected;
        begin
            sw = value;
            wait_display(expected, 32'd30000);
        end
    endtask

    task send_ps2_bit;
        input value;
        integer i;
        begin
            ps2_data = value;
            for (i = 0; i < 30; i = i + 1) @(posedge clk);
            ps2_clk = 1'b0;
            for (i = 0; i < 30; i = i + 1) @(posedge clk);
            ps2_clk = 1'b1;
            for (i = 0; i < 30; i = i + 1) @(posedge clk);
        end
    endtask

    task send_ps2_byte;
        input [7:0] value;
        integer i;
        reg parity;
        begin
            parity = ~^value;
            send_ps2_bit(1'b0);
            for (i = 0; i < 8; i = i + 1)
                send_ps2_bit(value[i]);
            send_ps2_bit(parity);
            send_ps2_bit(1'b1);
            ps2_data = 1'b1;
        end
    endtask

    task report_interval;
        input [8*16-1:0] name;
        input integer first;
        input integer last;
        reg [31:0] cycles;
        reg [31:0] instret;
        reg [31:0] stalls;
        reg [31:0] flushes;
        begin
            cycles = mark_cycle[last] - mark_cycle[first];
            instret = mark_instret[last] - mark_instret[first];
            stalls = mark_stall[last] - mark_stall[first];
            flushes = mark_flush[last] - mark_flush[first];
            if (instret == 0) begin
                $display("FAIL: zero retired instructions in benchmark interval %s", name);
                $finish;
            end
            $display("PERF %-16s cycles=%0d instret=%0d CPIx100=%0d stall=%0d flush=%0d",
                     name, cycles, instret, (cycles * 100) / instret, stalls, flushes);
        end
    endtask

    always @(posedge dut.cpu_clk) begin
        if (rst_n && dut.dmem_req && dut.dmem_we && dut.dmem_ack && dut.dmem_addr == 32'h00000380) begin
            if (dut.dmem_wdata >= 32'h51 && dut.dmem_wdata <= 32'h55 &&
                marker_seen == (dut.dmem_wdata - 32'h51)) begin
                mark_cycle[marker_seen] <= debug_cycle;
                mark_instret[marker_seen] <= debug_instret;
                mark_stall[marker_seen] <= debug_stall;
                mark_flush[marker_seen] <= debug_flush;
                marker_seen <= marker_seen + 1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        sw = 16'h0000;
        btn = 5'b0;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        marker_seen = 0;

        repeat (12) @(posedge clk);
        rst_n = 1'b1;

        wait_display(32'h600dc0de, 32'd30000);
        if (led !== 16'hffff) begin
            $display("FAIL: self-test LED mask expected ffff, got %h", led);
            $finish;
        end

        set_switch_and_wait(16'h1123, 32'h10001123);
        if (led !== 16'h1123) begin
            $display("FAIL: MMIO mirror LED expected 1123, got %h", led);
            $finish;
        end

        set_switch_and_wait(16'h2012, 32'h2000129e);
        if (led !== 16'h009e) begin
            $display("FAIL: ALU page LED expected 009e, got %h", led);
            $finish;
        end

        set_switch_and_wait(16'h3005, 32'h3000001a);
        if (led !== 16'hffff) begin
            $display("FAIL: memory page did not report success, led=%h", led);
            $finish;
        end

        set_switch_and_wait(16'h400a, 32'h400a0037);

        sw = 16'h5000;
    end

    initial begin : benchmark_and_io
        integer timeout;
        wait (rst_n == 1'b1);
        wait (sw == 16'h5000);
        timeout = 0;
        while (marker_seen < 5 && timeout < 100000) begin
            @(posedge dut.cpu_clk);
            timeout = timeout + 1;
        end
        if (marker_seen < 5) begin
            $display("FAIL: benchmark markers incomplete: %0d/5 pc=%h", marker_seen, debug_pc);
            $finish;
        end
        report_interval("ALU/forwarding", 0, 1);
        report_interval("load-use", 1, 2);
        report_interval("taken-branch", 2, 3);
        report_interval("cache-conflict", 3, 4);

        repeat (2000) @(posedge dut.cpu_clk);
        if ((displayed_word() >> 28) !== 4'h5) begin
            $display("FAIL: benchmark result page not displayed, display=%h", displayed_word());
            $finish;
        end
        sw = 16'h6000;
        repeat (2000) @(posedge dut.cpu_clk);
        if (dut.u_dmem.u_backend.mem[16'h081] < 6 || dut.u_dmem.u_backend.mem[16'h082] != 10) begin
            $display("FAIL: switch IRQ dashboard count=%0d claim=%0d",
                     dut.u_dmem.u_backend.mem[16'h081], dut.u_dmem.u_backend.mem[16'h082]);
            $finish;
        end
        if (meip !== 1'b0) begin
            $display("FAIL: meip remained asserted after switch interrupt");
            $finish;
        end

        sw = 16'h7000;
        repeat (2000) @(posedge dut.cpu_clk);
        send_ps2_byte(8'h1c);
        repeat (4000) @(posedge dut.cpu_clk);
        if (dut.u_dmem.u_backend.mem[16'h083] !== 32'h1c || dut.u_dmem.u_backend.mem[16'h084] < 1) begin
            $display("FAIL: first PS/2 byte code=%h count=%0d",
                     dut.u_dmem.u_backend.mem[16'h083], dut.u_dmem.u_backend.mem[16'h084]);
            $finish;
        end
        send_ps2_byte(8'h1b);
        repeat (4000) @(posedge dut.cpu_clk);
        if (dut.u_dmem.u_backend.mem[16'h083] !== 32'h1b || dut.u_dmem.u_backend.mem[16'h084] < 2) begin
            $display("FAIL: second PS/2 byte code=%h count=%0d",
                     dut.u_dmem.u_backend.mem[16'h083], dut.u_dmem.u_backend.mem[16'h084]);
            $finish;
        end

        sw = 16'h8000;
        wait_display(32'h88000000, 32'd10000);
        press_button_and_wait(5'b00001, 16'd1);
        press_button_and_wait(5'b00010, 16'd2);
        press_button_and_wait(5'b00100, 16'd3);
        press_button_and_wait(5'b01000, 16'd4);
        press_button_and_wait(5'b10000, 16'd5);
        press_button_and_wait(5'b10101, 16'd6);
        if (dut.u_dmem.u_backend.mem[16'h085] !== 32'h15 ||
            dut.u_dmem.u_backend.mem[16'h086] !== 32'd6 ||
            dut.u_dmem.u_backend.mem[16'h082] !== 32'd8 ||
            led !== 16'h0035 || meip !== 1'b0) begin
            $display("FAIL: button dashboard value=%h count=%0d claim=%0d led=%h meip=%b",
                     dut.u_dmem.u_backend.mem[16'h085], dut.u_dmem.u_backend.mem[16'h086],
                     dut.u_dmem.u_backend.mem[16'h082], led, meip);
            $finish;
        end

        $display("PASS: complete system acceptance demo passed; cycle=%0d instret=%0d stall=%0d flush=%0d",
                 debug_cycle, debug_instret, debug_stall, debug_flush);
        $finish;
    end
endmodule
