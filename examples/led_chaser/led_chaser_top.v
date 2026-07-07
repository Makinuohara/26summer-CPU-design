module led_chaser_top (
    input wire CLK100MHZ,
    output wire [15:0] LED
);
    reg [27:0] counter = 28'b0;

    always @(posedge CLK100MHZ) begin
        counter <= counter + 1'b1;
    end

    assign LED = 16'h0001 << counter[27:24];
endmodule
