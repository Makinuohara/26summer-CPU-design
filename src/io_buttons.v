module io_buttons (
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
    input wire [4:0] btn
);
    reg [4:0] btn_meta;
    reg [4:0] btn_sync;
    reg [4:0] btn_prev;
    reg        irq_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_meta     <= 5'b0;
            btn_sync     <= 5'b0;
            btn_prev     <= 5'b0;
            irq_pending  <= 1'b0;
        end else begin
            btn_meta <= btn;
            btn_sync <= btn_meta;
            btn_prev <= btn_sync;

            if (|(btn_sync & ~btn_prev))
                irq_pending <= 1'b1;
            else if (dmem_cs && !dmem_we)
                irq_pending <= 1'b0;
        end
    end

    assign dmem_ack   = dmem_cs;
    assign dmem_rdata = (dmem_cs && !dmem_we) ? {27'b0, btn_sync} : 32'b0;
    assign dmem_fault = dmem_cs && (dmem_we || dmem_width != 2'b00 || dmem_addr[1:0] != 2'b00);
    assign dmem_irq   = irq_pending;

    wire unused_wdata = ^dmem_wdata;
endmodule
