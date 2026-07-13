`timescale 1ns / 1ps

module tb_bench_ipc;
    reg clk;
    reg rst_n;
    reg [15:0] sw;
    wire [15:0] led;
    wire [31:0] debug_pc;
    integer timeout;
    integer i;
    reg [31:0] ipc_value;
    reg [31:0] expected_display;

    soc #(
        .CLK_DIV_BITS(1),
        .IMEM_INIT_FILE("sim/bench_ipc.hex"),
        .IMEM_LATENCY(1),
        .DMEM_LATENCY(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sw(sw),
        .btn(5'b0),
        .ps2_clk(1'b1),
        .ps2_data(1'b1),
        .led(led),
        .seg(),
        .an(),
        .dp(),
        .debug_pc(debug_pc),
        .debug_cycle(),
        .debug_instret(),
        .debug_stall(),
        .debug_flush(),
        .debug_x5(),
        .debug_seg_value(),
        .meip()
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

    task select_and_check;
        input [1:0] index;
        integer wait_cycles;
        begin
            sw = {14'b0, index};
            ipc_value = dut.u_dmem.u_backend.mem[16'h088 + index];
            expected_display = ((index + 1) << 28) | (ipc_value & 32'h0000_ffff);
            wait_cycles = 0;
            while (displayed_word() !== expected_display && wait_cycles < 20000) begin
                @(posedge dut.cpu_clk);
                wait_cycles = wait_cycles + 1;
            end
            if (displayed_word() !== expected_display ||
                led !== (((index + 1) << 8) | (ipc_value & 32'hff))) begin
                $display("FAIL: test=%0d ipc100=%0d display=%h expected=%h led=%h pc=%h",
                         index + 1, ipc_value, displayed_word(), expected_display, led, debug_pc);
                $finish;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        sw = 16'h0000;
        repeat (12) @(posedge clk);
        rst_n = 1'b1;

        timeout = 0;
        while ((dut.u_dmem.u_backend.mem[16'h088] == 0 ||
                dut.u_dmem.u_backend.mem[16'h089] == 0 ||
                dut.u_dmem.u_backend.mem[16'h08a] == 0 ||
                dut.u_dmem.u_backend.mem[16'h08b] == 0) && timeout < 150000) begin
            @(posedge dut.cpu_clk);
            timeout = timeout + 1;
        end
        if (timeout == 150000) begin
            $display("FAIL: IPC benchmark initialization timed out, pc=%h", debug_pc);
            $finish;
        end

        // Visit every selection; finish at 0 so selection 0 also gets an edge.
        select_and_check(2'd1);
        select_and_check(2'd2);
        select_and_check(2'd3);
        select_and_check(2'd0);

        for (i = 0; i < 4; i = i + 1) begin
            $display("PERF test=%0d cycles=%0d instret=%0d CPIx100=%0d IPCx100=%0d",
                     i + 1,
                     dut.u_dmem.u_backend.mem[16'h080 + i * 2],
                     dut.u_dmem.u_backend.mem[16'h081 + i * 2],
                     (dut.u_dmem.u_backend.mem[16'h080 + i * 2] * 100) /
                      dut.u_dmem.u_backend.mem[16'h081 + i * 2],
                     dut.u_dmem.u_backend.mem[16'h088 + i]);
        end
        $display("PASS: standalone IPC benchmark display passed");
        $finish;
    end
endmodule
