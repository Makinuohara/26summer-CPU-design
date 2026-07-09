module io_leds (
    input wire clk,
    input wire rst_n,
    input wire dmem_cs,
    input wire [31:0] dmem_addr,
    input wire dmem_we,
    input wire [31:0] dmem_wdata,
    input wire [1:0] dmem_width,
    output wire dmem_ack,
    output wire [31:0] dmem_rdata,
    output wire dmem_fault,
    output wire dmem_irq,
    output wire [15:0] led
);
    reg [15:0] led_reg;
    wire valid_access = dmem_width == 2'b00 && dmem_addr[1:0] == 2'b00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_reg <= 16'b0;
        end else if (dmem_cs && dmem_we && valid_access) begin
            led_reg <= {8'b0, dmem_wdata[7:0]};
        end
    end

    assign dmem_ack = dmem_cs;
    assign dmem_rdata = (dmem_cs && !dmem_we) ? {16'b0, led_reg} : 32'b0;
    assign dmem_fault = dmem_cs && !valid_access;
    assign dmem_irq = 1'b0;
    assign led = led_reg;
endmodule
