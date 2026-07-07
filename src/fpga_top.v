module fpga_top (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    input wire [1:0] SW,
    output wire [15:0] LED,
    output wire [6:0] SEG,
    output wire [7:0] AN,
    output wire DP
);
    wire rst = ~CPU_RESETN;
    wire slow_clk;
    wire [31:0] debug_pc;
    wire [31:0] debug_x5;
    wire [31:0] debug_mem0;
    reg [31:0] display_value;

    clk_div u_clk_div (
        .clk(CLK100MHZ),
        .rst(rst),
        .slow_clk(slow_clk)
    );

    cpu_top u_cpu_top (
        .clk(slow_clk),
        .rst(rst),
        .debug_pc(debug_pc),
        .debug_x5(debug_x5),
        .debug_mem0(debug_mem0)
    );

    always @(*) begin
        case (SW)
            2'b00: display_value = debug_pc;
            2'b01: display_value = debug_x5;
            2'b10: display_value = debug_mem0;
            default: display_value = 32'h20260707;
        endcase
    end

    seg7_hex u_seg7_hex (
        .hex(display_value[3:0]),
        .seg(SEG)
    );

    assign LED = display_value[15:0];
    assign AN = 8'b11111110;
    assign DP = 1'b1;
endmodule
