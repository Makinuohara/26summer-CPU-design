module io_ps2 (
    input wire clk,
    input wire clk_fast,
    input wire rst_n,
    input wire dmem_cs,
    input wire [31:0] dmem_addr,
    input wire dmem_we,
    input wire [31:0] dmem_wdata,
    input wire [1:0] dmem_width,
    output reg dmem_ack,
    output reg [31:0] dmem_rdata,
    output reg dmem_fault,
    output wire dmem_irq,
    input wire ps2_clk,
    input wire ps2_data
);
    // ==================================================================
    // PS/2 physical layer receiver (clk_fast domain, 100 MHz)
    // ==================================================================
    localparam [4:0] PS2_FILTER_COUNT = 5'd19;

    reg [1:0] ps2_clk_sync;
    reg [1:0] ps2_data_sync;
    reg [4:0] ps2_clk_stable_count;
    reg [4:0] ps2_data_stable_count;
    reg       ps2_clk_filt;
    reg       ps2_data_filt;
    reg       ps2_clk_filt_prev;
    reg [3:0] bit_count;
    reg [10:0] shift_reg;
    reg        receiving;
    reg [7:0]  rx_byte_fast;
    reg        rx_ready_fast;
    reg        f0_flag;
    reg        e0_flag;
    reg        rx_ack_toggle;
    reg        rx_ack_toggle_fast;
    reg        rx_ack_toggle_sync0;
    reg        rx_ack_toggle_sync1;
    reg        rx_ack_toggle_prev;
    wire is_service_byte = (shift_reg[8:1] == 8'hAA) || (shift_reg[8:1] == 8'hFA);

    always @(posedge clk_fast or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync  <= 2'b11;
            ps2_data_sync <= 2'b11;
            ps2_clk_stable_count  <= 5'd0;
            ps2_data_stable_count <= 5'd0;
            ps2_clk_filt  <= 1'b1;
            ps2_data_filt <= 1'b1;
            ps2_clk_filt_prev <= 1'b1;
            bit_count     <= 4'd0;
            shift_reg     <= 11'd0;
            receiving     <= 1'b0;
            rx_byte_fast  <= 8'd0;
            rx_ready_fast <= 1'b0;
            f0_flag       <= 1'b0;
            e0_flag       <= 1'b0;
            rx_ack_toggle_fast  <= 1'b0;
            rx_ack_toggle_sync0 <= 1'b0;
            rx_ack_toggle_sync1 <= 1'b0;
            rx_ack_toggle_prev  <= 1'b0;
        end else begin
            ps2_clk_sync  <= {ps2_clk_sync[0], ps2_clk};
            ps2_data_sync <= {ps2_data_sync[0], ps2_data};
            ps2_clk_filt_prev <= ps2_clk_filt;

            // Match Digilent's keyboard demo approach: ignore short
            // transients before treating PS/2 clock/data as stable.
            if (ps2_clk_sync[1] == ps2_clk_filt) begin
                ps2_clk_stable_count <= 5'd0;
            end else if (ps2_clk_stable_count == PS2_FILTER_COUNT) begin
                ps2_clk_filt <= ps2_clk_sync[1];
                ps2_clk_stable_count <= 5'd0;
            end else begin
                ps2_clk_stable_count <= ps2_clk_stable_count + 5'd1;
            end

            if (ps2_data_sync[1] == ps2_data_filt) begin
                ps2_data_stable_count <= 5'd0;
            end else if (ps2_data_stable_count == PS2_FILTER_COUNT) begin
                ps2_data_filt <= ps2_data_sync[1];
                ps2_data_stable_count <= 5'd0;
            end else begin
                ps2_data_stable_count <= ps2_data_stable_count + 5'd1;
            end

            // Synchronize ack toggle from clk domain
            rx_ack_toggle_sync0 <= rx_ack_toggle;
            rx_ack_toggle_sync1 <= rx_ack_toggle_sync0;
            rx_ack_toggle_prev  <= rx_ack_toggle_sync1;

            // Clear rx_ready when ack toggle edge detected
            if (rx_ack_toggle_sync1 != rx_ack_toggle_prev) begin
                rx_ready_fast <= 1'b0;
                rx_ack_toggle_fast <= rx_ack_toggle_sync1;
            end

            // PS/2 frame reception
            if (ps2_clk_filt_prev && !ps2_clk_filt) begin  // filtered falling edge of ps2_clk
                if (!receiving) begin
                    if (ps2_data_filt == 1'b0) begin  // start bit
                        receiving <= 1'b1;
                        bit_count <= 4'd1;
                        shift_reg <= 11'd0;
                        shift_reg[0] <= 1'b0;
                    end
                end else begin
                    if (bit_count == 4'd10) begin  // 11 bits received
                        receiving <= 1'b0;
                        bit_count <= 4'd0;
                        // Verify: start=0, stop=1, odd parity
                        if (shift_reg[0] == 1'b0 && ps2_data_filt == 1'b1 &&
                            (^shift_reg[9:1] == 1'b1)) begin
                            if (shift_reg[8:1] == 8'hF0) begin
                                f0_flag <= 1'b1;
                            end else if (shift_reg[8:1] == 8'hE0) begin
                                e0_flag <= 1'b1;
                            end else if (is_service_byte) begin
                                e0_flag <= 1'b0;
                            end else if (f0_flag) begin
                                f0_flag <= 1'b0;
                                e0_flag <= 1'b0;
                            end else if (!rx_ready_fast) begin
                                rx_byte_fast  <= shift_reg[8:1];
                                rx_ready_fast <= 1'b1;
                                e0_flag       <= 1'b0;
                            end
                        end
                    end else begin
                        shift_reg[bit_count] <= ps2_data_filt;
                        bit_count <= bit_count + 4'd1;
                    end
                end
            end
        end
    end

    // ==================================================================
    // CDC: rx_ready_fast -> clk domain (2-stage synchronizer)
    // ==================================================================
    reg rx_ready_sync0;
    reg rx_ready_sync1;
    reg rx_ready_consumed;
    reg [7:0] rx_byte_sync0;
    reg [7:0] rx_byte_sync1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_ready_sync0 <= 1'b0;
            rx_ready_sync1 <= 1'b0;
            rx_byte_sync0  <= 8'd0;
            rx_byte_sync1  <= 8'd0;
        end else begin
            rx_ready_sync0 <= rx_ready_fast;
            rx_ready_sync1 <= rx_ready_sync0;
            rx_byte_sync0  <= rx_byte_fast;
            rx_byte_sync1  <= rx_byte_sync0;
        end
    end

    // ==================================================================
    // Register interface (clk domain)
    // ==================================================================
    reg        ctrl_enable;
    reg        ctrl_irq_en;
    reg [7:0]  rdata_byte;
    reg        rdata_valid;
    reg [7:0]  shadow_byte;
    reg        shadow_valid;
    reg [31:0] ps2_ctrl;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_enable    <= 1'b0;
            ctrl_irq_en    <= 1'b0;
            rdata_byte     <= 8'd0;
            rdata_valid    <= 1'b0;
            shadow_byte    <= 8'd0;
            shadow_valid   <= 1'b0;
            rx_ready_consumed <= 1'b0;
            ps2_ctrl       <= 32'd0;
            rx_ack_toggle  <= 1'b0;
        end else begin
            if (!rx_ready_sync1)
                rx_ready_consumed <= 1'b0;

            // Consume each received byte once. If software has not read the
            // current byte yet, queue one more byte in shadow storage so short
            // key taps are not lost while the CPU is still servicing the
            // previous interrupt.
            if (rx_ready_sync1 && !rx_ready_consumed) begin
                if (ctrl_enable) begin
                    if (!rdata_valid) begin
                        rdata_byte  <= rx_byte_sync1;
                        rdata_valid <= 1'b1;
                    end else if (!shadow_valid) begin
                        shadow_byte  <= rx_byte_sync1;
                        shadow_valid <= 1'b1;
                    end else begin
                        shadow_byte <= rx_byte_sync1;
                    end
                end
                rx_ready_consumed <= 1'b1;
                rx_ack_toggle <= ~rx_ack_toggle;  // toggle to ack fast domain
            end

            if (dmem_cs && !dmem_we && dmem_addr[2] == 1'b1) begin
                if (shadow_valid) begin
                    rdata_byte   <= shadow_byte;
                    rdata_valid  <= 1'b1;
                    shadow_valid <= 1'b0;
                end else begin
                    rdata_valid <= 1'b0;
                end
            end

            // Write PS2_CTRL register
            if (dmem_cs && dmem_we && dmem_addr[2] == 1'b0) begin
                ctrl_enable <= dmem_wdata[0];
                ctrl_irq_en <= dmem_wdata[8];
                ps2_ctrl    <= {23'd0, dmem_wdata[8], 7'd0, dmem_wdata[0]};
                if (!dmem_wdata[0]) begin
                    rdata_valid  <= 1'b0;
                    shadow_valid <= 1'b0;
                end
            end
        end
    end

    // ==================================================================
    // Bus response (combinational)
    // ==================================================================
    always @(*) begin
        dmem_ack   = dmem_cs;
        dmem_fault = 1'b0;
        dmem_rdata = 32'd0;

        if (dmem_cs) begin
            if (dmem_addr[2] == 1'b0) begin
                // PS2_CTRL (offset 0x0)
                dmem_rdata = ps2_ctrl;
                if (dmem_we && dmem_width != 2'b00)
                    dmem_fault = 1'b1;
            end else begin
                // PS2_RDATA (offset 0x4)
                // [31:9] reserved, [8]=valid, [7:0]=raw scan_code
                dmem_rdata = {23'd0, rdata_valid, rdata_byte};
                if (dmem_we)
                    dmem_fault = 1'b1;
            end
        end
    end

    assign dmem_irq = rdata_valid && ctrl_irq_en;
endmodule
