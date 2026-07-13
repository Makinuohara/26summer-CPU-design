module perf_reader (
    input  wire [31:0] debug_cycle,
    input  wire [31:0] debug_instret,
    input  wire        dmem_cs,
    input  wire [31:0] dmem_addr,
    input  wire        dmem_we,
    input  wire [31:0] dmem_wdata,
    input  wire [1:0]  dmem_width,
    output wire        dmem_ack,
    output wire [31:0] dmem_rdata,
    output wire        dmem_fault,
    output wire        dmem_irq
);
    wire valid_access = dmem_width == 2'b00 && dmem_addr[1:0] == 2'b00;
    wire is_cycle  = dmem_addr[2] == 1'b0;
    wire is_instret = dmem_addr[2] == 1'b1;

    assign dmem_ack   = dmem_cs;
    assign dmem_rdata = (dmem_cs && !dmem_we && valid_access)
                        ? (is_instret ? debug_instret : debug_cycle)
                        : 32'b0;
    assign dmem_fault = dmem_cs && (dmem_we || !valid_access);
    assign dmem_irq   = 1'b0;

    wire unused_wdata = ^dmem_wdata;
endmodule
