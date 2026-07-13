`timescale 1ns / 1ps

module tb_perf_reader;
    reg [31:0] debug_cycle;
    reg [31:0] debug_instret;
    reg dmem_cs;
    reg [31:0] dmem_addr;
    reg dmem_we;
    reg [31:0] dmem_wdata;
    reg [1:0] dmem_width;
    wire dmem_ack;
    wire [31:0] dmem_rdata;
    wire dmem_fault;
    wire dmem_irq;

    perf_reader dut (
        .debug_cycle(debug_cycle),
        .debug_instret(debug_instret),
        .dmem_cs(dmem_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(dmem_ack),
        .dmem_rdata(dmem_rdata),
        .dmem_fault(dmem_fault),
        .dmem_irq(dmem_irq)
    );

    initial begin
        debug_cycle = 32'd1234;
        debug_instret = 32'd567;
        dmem_cs = 1'b1;
        dmem_addr = 32'h80000038;
        dmem_we = 1'b0;
        dmem_wdata = 32'b0;
        dmem_width = 2'b00;
        #1;
        if (!dmem_ack || dmem_fault || dmem_rdata !== 32'd1234 || dmem_irq) begin
            $display("FAIL: PERF_CYCLE read ack=%b fault=%b data=%h irq=%b",
                     dmem_ack, dmem_fault, dmem_rdata, dmem_irq);
            $finish;
        end

        dmem_addr = 32'h8000003c;
        #1;
        if (dmem_fault || dmem_rdata !== 32'd567) begin
            $display("FAIL: PERF_INSTRET read fault=%b data=%h", dmem_fault, dmem_rdata);
            $finish;
        end

        dmem_we = 1'b1;
        #1;
        if (!dmem_fault) begin
            $display("FAIL: performance counter write did not fault");
            $finish;
        end

        dmem_we = 1'b0;
        dmem_width = 2'b01;
        #1;
        if (!dmem_fault) begin
            $display("FAIL: non-word performance counter read did not fault");
            $finish;
        end

        $display("PASS: performance MMIO reader passed");
        $finish;
    end
endmodule
