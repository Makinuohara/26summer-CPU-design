`timescale 1ns / 1ps

module tb_cpu_top;
    reg clk;
    reg rst;
    wire [31:0] debug_pc;
    wire [31:0] debug_x5;
    wire [31:0] debug_mem0;

    cpu_top dut (
        .clk(clk),
        .rst(rst),
        .debug_pc(debug_pc),
        .debug_x5(debug_x5),
        .debug_mem0(debug_mem0)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        #20;
        rst = 1'b0;

        repeat (30) @(posedge clk);

        if (debug_x5 !== 32'h00000001) begin
            $display("FAIL: x5 expected 1, got %h", debug_x5);
            $finish;
        end

        if (debug_mem0 !== 32'h0000000c) begin
            $display("FAIL: mem[0] expected 12, got %h", debug_mem0);
            $finish;
        end

        $display("PASS: single-cycle RV32I subset smoke test passed");
        $finish;
    end
endmodule
