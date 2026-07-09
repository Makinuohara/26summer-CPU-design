`timescale 1ns / 1ps

module clk_div #(
    parameter DIV_BITS = 25
) (
    input wire clk,
    input wire rst,
    output wire slow_clk
);
    reg [DIV_BITS-1:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= {DIV_BITS{1'b0}};
        end else begin
            counter <= counter + 1'b1;
        end
    end

    assign slow_clk = counter[DIV_BITS-1];
endmodule
