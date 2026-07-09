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

    function [31:0] rom_word;
        input [31:0] addr;
        begin
            case (addr[31:2])
                30'h00000000: rom_word = 32'h1400_0093;
                30'h00000001: rom_word = 32'h3050_9073;
                30'h00000002: rom_word = 32'h00c0_0113;
                30'h00000003: rom_word = 32'h0020_2023;
                30'h00000004: rom_word = 32'h0000_2183;
                30'h00000005: rom_word = 32'h0030_2223;
                30'h00000006: rom_word = 32'h8100_05b7;
                30'h00000007: rom_word = 32'h0010_0613;
                30'h00000008: rom_word = 32'h00c5_a223;
                30'h00000009: rom_word = 32'h8100_26b7;
                30'h0000000a: rom_word = 32'h0020_0613;
                30'h0000000b: rom_word = 32'h00c6_a023;
                30'h0000000c: rom_word = 32'h8120_0737;
                30'h0000000d: rom_word = 32'h0007_2023;
                30'h0000000e: rom_word = 32'h0000_1637;
                30'h0000000f: rom_word = 32'h8006_0613;
                30'h00000010: rom_word = 32'h3046_2073;
                30'h00000011: rom_word = 32'h0080_0613;
                30'h00000012: rom_word = 32'h3006_2073;
                30'h00000013: rom_word = 32'h8000_0237;
                30'h00000014: rom_word = 32'h0082_2283;
                30'h00000015: rom_word = 32'h0302_2383;
                30'h00000016: rom_word = 32'h0000_0013;
                30'h00000017: rom_word = 32'h0072_82b3;
                30'h00000018: rom_word = 32'h00c0_2503;
                30'h00000019: rom_word = 32'h00a2_82b3;
                30'h0000001a: rom_word = 32'h0032_8433;
                30'h0000001b: rom_word = 32'h0080_2223;
                30'h0000001c: rom_word = 32'h0040_2483;
                30'h0000001d: rom_word = 32'h0052_2623;
                30'h0000001e: rom_word = 32'h0052_2823;
                30'h0000001f: rom_word = 32'hfd5ff06f;
                30'h00000050: rom_word = 32'h0047_2503;
                30'h00000051: rom_word = 32'h0013_0313;
                30'h00000052: rom_word = 32'h0100_0593;
                30'h00000053: rom_word = 32'h00b0_2623;
                30'h00000054: rom_word = 32'h0010_0593;
                30'h00000055: rom_word = 32'h00b0_2423;
                30'h00000056: rom_word = 32'h00b7_2223;
                30'h00000057: rom_word = 32'h3020_0073;
                default: rom_word = 32'h0000_0013;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            addr_q <= 32'b0;
            wait_q <= 2'b00;
            imem_ack <= 1'b0;
            imem_data <= 32'h0000_0013;
        end else begin
            imem_ack <= 1'b0;
            if (!busy) begin
                if (imem_req) begin
                    busy <= 1'b1;
                    addr_q <= imem_addr;
                    wait_q <= 2'd1;
                end
            end else if (wait_q != 0) begin
                wait_q <= wait_q - 1'b1;
            end else begin
                busy <= 1'b0;
                imem_ack <= 1'b1;
                imem_data <= rom_word(addr_q);
            end
        end
    end
endmodule
