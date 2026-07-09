`timescale 1ns / 1ps

module tb_pipeline_memory_integration;
    reg clk;
    reg rst_n;

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
        .debug_pc(debug_pc),
        .debug_cycle(debug_cycle),
        .debug_instret(debug_instret),
        .debug_stall(debug_stall),
        .debug_flush(debug_flush),
        .debug_x5(debug_x5)
    );

    imem #(
        .ADDR_WIDTH(8),
        .MEM_LATENCY(2),
        .INIT_FILE("sim/pipeline_memory_integration_imem.hex")
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
        .sw_ack(1'b0),
        .sw_rdata(32'b0),
        .sw_fault(1'b0),
        .led_cs(led_cs),
        .led_ack(1'b0),
        .led_rdata(32'b0),
        .led_fault(1'b0),
        .seg_cs(seg_cs),
        .seg_ack(1'b0),
        .seg_rdata(32'b0),
        .seg_fault(1'b0),
        .btn_cs(btn_cs),
        .btn_ack(1'b0),
        .btn_rdata(32'b0),
        .btn_fault(1'b0),
        .intc_cs(intc_cs),
        .intc_ack(1'b0),
        .intc_rdata(32'b0),
        .intc_fault(1'b0)
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        repeat (6) @(posedge clk);
        rst_n = 1'b1;

        repeat (200) @(posedge clk);

        if (debug_x5 !== 32'h00000001) begin
            $display("FAIL: x5 expected 1, got %h", debug_x5);
            $display("INFO: pc=%h cycle=%0d instret=%0d stall=%0d flush=%0d x3=%h x4=%h mem0=%h",
                     debug_pc, debug_cycle, debug_instret, debug_stall, debug_flush,
                     dut.u_regfile.regs[3], dut.u_regfile.regs[4], u_dmem.u_backend.mem[0]);
            $display("CACHE: state=%0d valid0=%b tag0=%h line00=%h fill0=%h fill1=%h fill2=%h fill3=%h",
                     u_dmem.u_cache.state, u_dmem.u_cache.valid[0], u_dmem.u_cache.tags[0],
                     u_dmem.u_cache.lines[0][0],
                     u_dmem.u_cache.fill_buffer[0], u_dmem.u_cache.fill_buffer[1],
                     u_dmem.u_cache.fill_buffer[2], u_dmem.u_cache.fill_buffer[3]);
            $finish;
        end

        if (dut.u_regfile.regs[3] !== 32'h0000000c) begin
            $display("FAIL: x3 expected 12, got %h", dut.u_regfile.regs[3]);
            $finish;
        end

        if (dut.u_regfile.regs[4] !== 32'h0000000c) begin
            $display("FAIL: x4 expected 12, got %h", dut.u_regfile.regs[4]);
            $finish;
        end

        if (u_dmem.u_backend.mem[0] !== 32'h0000000c) begin
            $display("FAIL: dmem[0] expected 12, got %h", u_dmem.u_backend.mem[0]);
            $finish;
        end

        if (debug_stall == 32'b0) begin
            $display("FAIL: expected non-zero stalls from imem/dmem wait states");
            $finish;
        end

        if (debug_flush == 32'b0) begin
            $display("FAIL: expected non-zero flush count");
            $finish;
        end

        $display("PASS: CPU-memory integration passed; cycle=%0d instret=%0d stall=%0d flush=%0d",
                 debug_cycle, debug_instret, debug_stall, debug_flush);
        $finish;
    end

endmodule
