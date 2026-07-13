`timescale 1ns / 1ps

module fpga_muldiv_demo_top #(
    parameter CLK_DIV_BITS = 18
) (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    input wire [15:0] SW,
    input wire BTNL,
    input wire BTND,
    input wire BTNR,
    input wire BTNU,
    input wire BTNC,
    input wire PS2_CLK,
    input wire PS2_DATA,
    output wire [15:0] LED,
    output wire [6:0] SEG,
    output wire DP,
    output wire [7:0] AN
);
    wire unused_inputs = (^SW) ^ BTNL ^ BTND ^ BTNR ^ BTNU ^ BTNC;

    soc #(
        .CLK_DIV_BITS(CLK_DIV_BITS),
        .IMEM_INIT_FILE("muldiv_demo.mem")
    ) u_soc (
        .clk(CLK100MHZ),
        .rst_n(CPU_RESETN),
        .sw(16'b0),
        .btn(5'b0),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .led(LED),
        .seg(SEG),
        .an(AN),
        .dp(DP),
        .debug_pc(),
        .debug_cycle(),
        .debug_instret(),
        .debug_stall(),
        .debug_flush(),
        .debug_x5(),
        .debug_seg_value(),
        .meip()
    );
endmodule
