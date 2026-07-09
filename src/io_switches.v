module io_switches (
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
    input wire [15:0] sw
);
    reg [15:0] sw_meta;
    reg [15:0] sw_sync;
    reg [15:0] sw_prev;
    reg        irq_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw_meta     <= 16'b0;
            sw_sync     <= 16'b0;
            sw_prev     <= 16'b0;
            irq_pending <= 1'b0;
        end else begin
            sw_meta <= sw;
            sw_sync <= sw_meta;
            sw_prev <= sw_sync;

            if (sw_sync != sw_prev)
                irq_pending <= 1'b1;
            else if (dmem_cs && !dmem_we)
                irq_pending <= 1'b0;
        end
    end

    assign dmem_ack   = dmem_cs;
    assign dmem_rdata = (dmem_cs && !dmem_we) ? {16'b0, sw_sync} : 32'b0;
    assign dmem_fault = dmem_cs && (dmem_we || dmem_width != 2'b00 || dmem_addr[1:0] != 2'b00);
    assign dmem_irq   = irq_pending;

    wire unused_wdata = ^dmem_wdata;
endmodule
