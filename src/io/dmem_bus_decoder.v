module dmem_bus_decoder (
    input wire dmem_req,
    input wire [31:0] dmem_addr,
    // input wire dmem_we,
    // input wire [31:0] dmem_wdata,
    // input wire [1:0] dmem_width,
    output wire dmem_ack,
    output wire [31:0] dmem_rdata,
    output wire dmem_fault,

    output wire mem_cs,
    input wire mem_ack,
    input wire [31:0] mem_rdata,
    input wire mem_fault,

    output wire ps2_cs,
    input wire ps2_ack,
    input wire [31:0] ps2_rdata,
    input wire ps2_fault,

    output wire sw_cs,
    input wire sw_ack,
    input wire [31:0] sw_rdata,
    input wire sw_fault,

    output wire led_cs,
    input wire led_ack,
    input wire [31:0] led_rdata,
    input wire led_fault,

    output wire seg_cs,
    input wire seg_ack,
    input wire [31:0] seg_rdata,
    input wire seg_fault,

    output wire btn_cs,
    input wire btn_ack,
    input wire [31:0] btn_rdata,
    input wire btn_fault,

    output wire intc_cs,
    input wire intc_ack,
    input wire [31:0] intc_rdata,
    input wire intc_fault
);
    wire hit_mem = dmem_addr < 32'h08000000;
    wire hit_ps2 = dmem_addr >= 32'h80000000 && dmem_addr <= 32'h80000007;
    wire hit_sw = dmem_addr >= 32'h80000008 && dmem_addr <= 32'h8000000b;
    wire hit_led = dmem_addr >= 32'h8000000c && dmem_addr <= 32'h8000000f;
    wire hit_seg = dmem_addr >= 32'h80000010 && dmem_addr <= 32'h8000002f;
    wire hit_btn = dmem_addr >= 32'h80000030 && dmem_addr <= 32'h80000033;
    wire hit_intc = dmem_addr >= 32'h81000000 && dmem_addr <= 32'h81200007;
    wire miss = !(hit_mem || hit_ps2 || hit_sw || hit_led || hit_seg || hit_btn || hit_intc);

    assign mem_cs = dmem_req && hit_mem;
    assign ps2_cs = dmem_req && hit_ps2;
    assign sw_cs = dmem_req && hit_sw;
    assign led_cs = dmem_req && hit_led;
    assign seg_cs = dmem_req && hit_seg;
    assign btn_cs = dmem_req && hit_btn;
    assign intc_cs = dmem_req && hit_intc;

    assign dmem_ack = (mem_cs && mem_ack) ||
                      (ps2_cs && ps2_ack) ||
                      (sw_cs && sw_ack) ||
                      (led_cs && led_ack) ||
                      (seg_cs && seg_ack) ||
                      (btn_cs && btn_ack) ||
                      (intc_cs && intc_ack) ||
                      (dmem_req && miss);

    assign dmem_rdata = mem_cs ? mem_rdata :
                        ps2_cs ? ps2_rdata :
                        sw_cs ? sw_rdata :
                        led_cs ? led_rdata :
                        seg_cs ? seg_rdata :
                        btn_cs ? btn_rdata :
                        intc_cs ? intc_rdata :
                        32'b0;

    assign dmem_fault = (mem_cs && mem_fault) ||
                        (ps2_cs && ps2_fault) ||
                        (sw_cs && sw_fault) ||
                        (led_cs && led_fault) ||
                        (seg_cs && seg_fault) ||
                        (btn_cs && btn_fault) ||
                        (intc_cs && intc_fault) ||
                        (dmem_req && miss);

    // wire unused_inputs = dmem_we ^ dmem_wdata[0] ^ dmem_width[0];
endmodule
