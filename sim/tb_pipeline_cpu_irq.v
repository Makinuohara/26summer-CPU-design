`timescale 1ns / 1ps

module tb_pipeline_cpu_irq;
    reg clk;
    reg rst_n;
    reg meip;

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

    assign imem_ack = imem_req;
    assign dmem_ack = dmem_req;
    assign dmem_rdata = 32'b0;
    assign dmem_fault = 1'b0;

    reg [31:0] instr_word;

    always @(*) begin
        case (imem_addr)
            32'h0000_0000: instr_word = 32'h0800_0093; // addi x1, x0, 0x80
            32'h0000_0004: instr_word = 32'h3050_9073; // csrrw x0, mtvec, x1
            32'h0000_0008: instr_word = 32'h0000_10b7; // lui x1, 0x1
            32'h0000_000c: instr_word = 32'h8000_8093; // addi x1, x1, -2048
            32'h0000_0010: instr_word = 32'h3040_a073; // csrrs x0, mie, x1
            32'h0000_0014: instr_word = 32'h0080_0093; // addi x1, x0, 8
            32'h0000_0018: instr_word = 32'h3000_a073; // csrrs x0, mstatus, x1
            32'h0000_001c: instr_word = 32'h0012_8293; // addi x5, x5, 1
            32'h0000_0020: instr_word = 32'hffdff06f; // jal x0, 0x1c
            32'h0000_0080: instr_word = 32'h0013_0313; // addi x6, x6, 1
            32'h0000_0084: instr_word = 32'h3420_23f3; // csrrs x7, mcause, x0
            32'h0000_0088: instr_word = 32'h3410_2473; // csrrs x8, mepc, x0
            32'h0000_008c: instr_word = 32'h3020_0073; // mret
            default: instr_word = 32'h0000_0013;
        endcase
    end

    assign imem_data = instr_word;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        meip = 1'b0;

        repeat (6) @(posedge clk);
        rst_n = 1'b1;

        repeat (24) @(posedge clk);
        meip = 1'b1;

        wait (debug_pc == 32'h0000_0080);
        @(posedge clk);
        meip = 1'b0;

        repeat (40) @(posedge clk);

        if (dut.u_regfile.regs[6] !== 32'h0000_0001) begin
            $display("FAIL: x6 expected 1 trap count, got %h", dut.u_regfile.regs[6]);
            $finish;
        end

        if (dut.u_regfile.regs[7] !== 32'h8000_000b) begin
            $display("FAIL: x7 expected mcause=0x8000000b, got %h", dut.u_regfile.regs[7]);
            $finish;
        end

        if ((dut.u_regfile.regs[8] !== 32'h0000_001c) && (dut.u_regfile.regs[8] !== 32'h0000_0020)) begin
            $display("FAIL: x8 expected mepc in loop body, got %h", dut.u_regfile.regs[8]);
            $finish;
        end

        if (debug_x5 < 32'd3) begin
            $display("FAIL: x5 expected to keep running after mret, got %0d", debug_x5);
            $finish;
        end

        if (debug_flush == 32'b0) begin
            $display("FAIL: expected flush count to increase for trap flow");
            $finish;
        end

        $display("PASS: CPU interrupt flow passed; cycle=%0d instret=%0d flush=%0d x5=%0d mepc=%h",
                 debug_cycle, debug_instret, debug_flush, debug_x5, dut.u_regfile.regs[8]);
        $finish;
    end

endmodule
