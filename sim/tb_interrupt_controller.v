`timescale 1ns / 1ps

module tb_interrupt_controller;
    reg clk;
    reg rst_n;
    reg dmem_cs;
    reg [31:0] dmem_addr;
    reg dmem_we;
    reg [31:0] dmem_wdata;
    reg [1:0] dmem_width;
    reg [15:0] irq_sources;
    reg [31:0] last_rdata;
    reg last_ack;
    reg last_fault;
    wire dmem_ack;
    wire [31:0] dmem_rdata;
    wire dmem_fault;
    wire dmem_irq;
    wire meip;

    interrupt_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .dmem_cs(dmem_cs),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_width(dmem_width),
        .dmem_ack(dmem_ack),
        .dmem_rdata(dmem_rdata),
        .dmem_fault(dmem_fault),
        .dmem_irq(dmem_irq),
        .irq_sources(irq_sources),
        .meip(meip)
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
        input [31:0] addr;
        input [31:0] data;
        begin
            dmem_cs = 1'b1;
            dmem_addr = addr;
            dmem_we = 1'b1;
            dmem_wdata = data;
            dmem_width = 2'b00;
            cycle();
            dmem_cs = 1'b0;
            dmem_we = 1'b0;
            dmem_wdata = 32'b0;
            cycle();
        end
    endtask

    task bus_read;
        input [31:0] addr;
        begin
            dmem_cs = 1'b1;
            dmem_addr = addr;
            dmem_we = 1'b0;
            dmem_wdata = 32'b0;
            dmem_width = 2'b00;
            cycle();
            last_rdata = dmem_rdata;
            last_ack = dmem_ack;
            last_fault = dmem_fault;
            dmem_cs = 1'b0;
            cycle();
        end
    endtask

    initial begin
        rst_n = 1'b0;
        dmem_cs = 1'b0;
        dmem_addr = 32'b0;
        dmem_we = 1'b0;
        dmem_wdata = 32'b0;
        dmem_width = 2'b00;
        irq_sources = 16'b0;
        last_rdata = 32'b0;
        last_ack = 1'b0;
        last_fault = 1'b0;
        cycle();
        rst_n = 1'b1;
        cycle();

        bus_write(32'h81000008, 32'd3);       // priority[2]
        bus_write(32'h81000020, 32'd5);       // priority[8]
        bus_write(32'h81000028, 32'd6);       // priority[10]
        bus_write(32'h81002000, 32'h00000504); // enable source 2, 8, 10
        bus_write(32'h81200000, 32'd0);       // threshold

        bus_read(32'h81000020);
        if (last_rdata !== 32'd5) begin
            $display("FAIL: priority[8] expected 5, got %h", last_rdata);
            $finish;
        end

        bus_read(32'h81002000);
        if (last_rdata[8] !== 1'b1 || last_rdata[2] !== 1'b1) begin
            $display("FAIL: enable register expected bits 8 and 2, got %h", last_rdata);
            $finish;
        end

        irq_sources = 16'h0104; // sources 2 and 8
        cycle();
        if (!meip || !dmem_irq) begin
            $display("FAIL: enabled pending interrupts should raise meip");
            $finish;
        end

        bus_read(32'h81200004); // claim
        if (last_rdata !== 32'd8) begin
            $display("FAIL: expected source 8 claim, got %h", last_rdata);
            $display("DIAG: irq=%h pending=%h enable=%h prio2=%0d prio8=%0d best=%0d threshold=%0d",
                     irq_sources, dut.pending, dut.enable, dut.prio[2], dut.prio[8], dut.best_id, dut.threshold);
            $finish;
        end

        cycle();
        bus_read(32'h81200004);
        if (last_rdata !== 32'd2) begin
            $display("FAIL: expected source 2 after source 8 claimed, got %h", last_rdata);
            $finish;
        end

        bus_write(32'h81200004, 32'd8); // complete source 8
        irq_sources[8] = 1'b0;
        cycle();
        bus_write(32'h81200004, 32'd2); // complete source 2
        irq_sources[2] = 1'b0;
        cycle();
        if (meip) begin
            $display("FAIL: meip should clear after completed sources drop");
            $finish;
        end

        bus_write(32'h81200000, 32'd5); // threshold masks priority <= 5
        irq_sources[8] = 1'b1;
        cycle();
        if (meip) begin
            $display("FAIL: threshold should mask source 8 priority 5");
            $finish;
        end

        irq_sources[10] = 1'b1;
        cycle();
        if (!meip) begin
            $display("FAIL: source 10 priority 6 should exceed threshold 5");
            $finish;
        end

        bus_read(32'h81001000);
        if (last_rdata[10] !== 1'b1 || last_rdata[8] !== 1'b1) begin
            $display("FAIL: pending register did not expose active sources, got %h", last_rdata);
            $finish;
        end

        bus_read(32'h81300000);
        if (!last_ack || !last_fault) begin
            $display("FAIL: unmapped PLIC offset should fault");
            $finish;
        end

        $display("PASS: interrupt controller passed");
        $finish;
    end
endmodule
