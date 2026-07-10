`timescale 1ns / 1ps

module fpga_demo_imem (
    input wire clk,
    input wire rst_n,
    input wire imem_req,
    input wire [31:0] imem_addr,
    output reg imem_ack,
    output reg [31:0] imem_data
);
    reg busy;
    reg [31:0] addr_q;
    reg [1:0] wait_q;
    reg resp_valid;
    reg [31:0] resp_data;

    function [31:0] rom_word;
        input [31:0] addr;
        begin
            case (addr[31:2])
                // Task-4 memory + interrupt + MMIO demo:
                // 1. Configure PLIC source 1 (switch interrupt).
                // 2. Enable machine external interrupt in CSR.
                // 3. Main loop continuously accesses dmem:
                //      x10 = dmem[0]
                //      x11 = dmem[1]
                //      dmem[2] = x10 + x11
                //      SEG = dmem[2]
                // 4. Trap handler:
                //    - reads SW to clear the switch-side pending flag
                //    - writes LED = SW | 0x10, so LED[4] is the interrupt marker
                //    - overwrites dmem[0] = SW | 0x10
                //    - claim/complete and mret
                //
                // Expected board behavior:
                // - Power-on: LED = 00, SEG = 03  (1 + 2)
                // - After SW=01 interrupt: LED = 11, SEG = 13  (0x11 + 0x02)
                // This proves normal dmem/cache access and interrupt-time MMIO
                // access can coexist, and the main loop continues after mret.
                30'h00000000: rom_word = 32'h8000_00b7; // lui   x1, 0x80000
                30'h00000001: rom_word = 32'h8100_0237; // lui   x4, 0x81000
                30'h00000002: rom_word = 32'h8120_02b7; // lui   x5, 0x81200
                30'h00000003: rom_word = 32'h0042_8293; // addi  x5, x5, 4
                30'h00000004: rom_word = 32'h8100_2637; // lui   x12,0x81002
                30'h00000005: rom_word = 32'h0010_0113; // addi  x2, x0, 1
                30'h00000006: rom_word = 32'h0020_0193; // addi  x3, x0, 2
                30'h00000007: rom_word = 32'h0000_a823; // sw    x0, 16(x1)
                30'h00000008: rom_word = 32'h0000_a623; // sw    x0, 12(x1)
                30'h00000009: rom_word = 32'h0020_2023; // sw    x2, 0(x0)
                30'h0000000a: rom_word = 32'h0030_2223; // sw    x3, 4(x0)
                30'h0000000b: rom_word = 32'h0000_2423; // sw    x0, 8(x0)
                30'h0000000c: rom_word = 32'h0022_2223; // sw    x2, 4(x4)
                30'h0000000d: rom_word = 32'h0036_2023; // sw    x3, 0(x12)
                30'h0000000e: rom_word = 32'hfe02_ae23; // sw    x0, -4(x5)
                30'h0000000f: rom_word = 32'h1000_0393; // addi  x7, x0, 0x100
                30'h00000010: rom_word = 32'h3053_9073; // csrrw x0, mtvec, x7
                30'h00000011: rom_word = 32'h0000_1337; // lui   x6, 0x1
                30'h00000012: rom_word = 32'h0013_5313; // srli  x6, x6, 1
                30'h00000013: rom_word = 32'h3043_2073; // csrrs x0, mie, x6
                30'h00000014: rom_word = 32'h0080_0393; // addi  x7, x0, 8
                30'h00000015: rom_word = 32'h3003_a073; // csrrs x0, mstatus, x7
                30'h00000016: rom_word = 32'h0000_2503; // loop: lw x10, 0(x0)
                30'h00000017: rom_word = 32'h0040_2583; //       lw x11, 4(x0)
                30'h00000018: rom_word = 32'h00b5_0633; //       add x12, x10, x11
                30'h00000019: rom_word = 32'h00c0_2423; //       sw x12, 8(x0)
                30'h0000001a: rom_word = 32'h00c0_a823; //       sw x12, 16(x1)
                30'h0000001b: rom_word = 32'hfedf_f06f; //       jal x0, loop

                // Trap handler at 0x100.
                30'h00000040: rom_word = 32'h0080_a403; // lw    x8, 8(x1)
                30'h00000041: rom_word = 32'h0104_6413; // ori   x8, x8, 0x10
                30'h00000042: rom_word = 32'h0080_a623; // sw    x8, 12(x1)
                30'h00000043: rom_word = 32'h0002_a583; // lw    x11, 0(x5)
                30'h00000044: rom_word = 32'h0080_2023; // sw    x8, 0(x0)
                30'h00000045: rom_word = 32'h00b2_a023; // sw    x11, 0(x5)
                30'h00000046: rom_word = 32'h3020_0073; // mret
                default: rom_word = 32'h0000_0013;
            endcase
        end
    endfunction

    always @(*) begin
        imem_ack = resp_valid;
        imem_data = resp_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            addr_q <= 32'b0;
            wait_q <= 2'b00;
            resp_valid <= 1'b0;
            resp_data <= 32'h0000_0013;
        end else begin
            if (resp_valid) begin
                resp_valid <= 1'b0;
            end

            if (!busy) begin
                if (!resp_valid && imem_req) begin
                    busy <= 1'b1;
                    addr_q <= imem_addr;
                    wait_q <= 2'd1;
                end
            end else if (wait_q != 0) begin
                wait_q <= wait_q - 1'b1;
            end else begin
                busy <= 1'b0;
                resp_valid <= 1'b1;
                resp_data <= rom_word(addr_q);
            end
        end
    end
endmodule
