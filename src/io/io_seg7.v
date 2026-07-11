module io_seg7 (
    input wire clk,
    input wire scan_clk,
    input wire rst_n,
    input wire dmem_cs,
    input wire [31:0] dmem_addr,
    input wire dmem_we,
    input wire [31:0] dmem_wdata,
    input wire [1:0] dmem_width,
    output wire dmem_ack,
    output reg [31:0] dmem_rdata,
    output wire dmem_fault,
    output wire dmem_irq,
    output reg [6:0] seg,
    output reg [7:0] an,
    output wire dp,
    output wire [7:0] debug_value
);
    reg enabled;
    reg [7:0] hex_value;
    reg [7:0] raw_digits [0:7];
    reg [15:0] scan_counter;
    // scan_clk is driven by the board 100 MHz clock in the current SoC top.
    // Use upper bits so the multiplex frequency lands in the visible, stable
    // range on the physical 7-seg display instead of effectively free-running.
    wire [2:0] scan_index = scan_counter[15:13];
    wire valid_access = dmem_width == 2'b00 && dmem_addr[1:0] == 2'b00;
    wire [3:0] reg_index = dmem_addr[5:2] - 4'd4;
    integer i;

    function [6:0] hex_to_seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex_to_seg = 7'b1000000;
                4'h1: hex_to_seg = 7'b1111001;
                4'h2: hex_to_seg = 7'b0100100;
                4'h3: hex_to_seg = 7'b0110000;
                4'h4: hex_to_seg = 7'b0011001;
                4'h5: hex_to_seg = 7'b0010010;
                4'h6: hex_to_seg = 7'b0000010;
                4'h7: hex_to_seg = 7'b1111000;
                4'h8: hex_to_seg = 7'b0000000;
                4'h9: hex_to_seg = 7'b0010000;
                4'ha: hex_to_seg = 7'b0001000;
                4'hb: hex_to_seg = 7'b0000011;
                4'hc: hex_to_seg = 7'b1000110;
                4'hd: hex_to_seg = 7'b0100001;
                4'he: hex_to_seg = 7'b0000110;
                4'hf: hex_to_seg = 7'b0001110;
                default: hex_to_seg = 7'b1111111;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enabled <= 1'b1;
            hex_value <= 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                raw_digits[i] <= 8'hff;
            end
        end else begin
            if (dmem_cs && dmem_we && valid_access) begin
                if (reg_index == 4'd0) begin
                    enabled <= 1'b1;
                    hex_value <= dmem_wdata[7:0];
                end else if (reg_index >= 4'd1 && reg_index <= 4'd8) begin
                    raw_digits[reg_index - 1'b1] <= dmem_wdata[7:0];
                end
            end
        end
    end

    always @(posedge scan_clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_counter <= 16'b0;
        end else begin
            scan_counter <= scan_counter + 1'b1;
        end
    end

    always @(*) begin
        dmem_rdata = 32'b0;
        if (dmem_cs && !dmem_we) begin
            if (reg_index == 4'd0) begin
                dmem_rdata = {24'b0, hex_value};
            end else if (reg_index >= 4'd1 && reg_index <= 4'd8) begin
                dmem_rdata = {24'b0, raw_digits[reg_index - 1'b1]};
            end
        end
    end

    always @(*) begin
        an = 8'b11111111;
        seg = 7'b1111111;
        if (enabled) begin
            case (scan_index)
                3'd0: begin
                    an[0] = 1'b0;
                    seg = hex_to_seg(hex_value[3:0]);
                end
                3'd1: begin
                    an[1] = 1'b0;
                    seg = hex_to_seg(hex_value[7:4]);
                end
                default: begin
                    seg = 7'b1111111;
                end
            endcase
        end
    end

    assign dmem_ack = dmem_cs;
    assign dmem_fault = dmem_cs && (!valid_access || reg_index > 4'd8);
    assign dmem_irq = 1'b0;
    assign dp = 1'b1;
    assign debug_value = hex_value;
endmodule
