`timescale 1ns / 1ps

module fpga_board_smoke_top (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    input wire [1:0] SW,
    output wire [15:0] LED,
    output reg [6:0] SEG,
    output wire [7:0] AN,
    output wire DP
);
    wire [3:0] display_value = {2'b00, SW};

    assign LED = {14'b0, SW};
    assign AN = 8'b1111_1110;
    assign DP = 1'b1;

    always @(*) begin
        case (display_value)
            4'h0: SEG = 7'b1000000;
            4'h1: SEG = 7'b1111001;
            4'h2: SEG = 7'b0100100;
            4'h3: SEG = 7'b0110000;
            4'h4: SEG = 7'b0011001;
            4'h5: SEG = 7'b0010010;
            4'h6: SEG = 7'b0000010;
            4'h7: SEG = 7'b1111000;
            4'h8: SEG = 7'b0000000;
            4'h9: SEG = 7'b0010000;
            4'ha: SEG = 7'b0001000;
            4'hb: SEG = 7'b0000011;
            4'hc: SEG = 7'b1000110;
            4'hd: SEG = 7'b0100001;
            4'he: SEG = 7'b0000110;
            4'hf: SEG = 7'b0001110;
            default: SEG = 7'b1111111;
        endcase
    end

    wire unused_inputs = CLK100MHZ ^ CPU_RESETN;
endmodule
