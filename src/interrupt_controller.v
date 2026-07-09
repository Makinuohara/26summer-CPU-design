module interrupt_controller (
    input wire clk,
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
    input wire [15:0] irq_sources,
    output wire meip
);
    reg [2:0] prio [0:15];
    reg [15:0] enable;
    reg [2:0] threshold;
    reg [15:0] claimed;
    integer i;

    wire [31:0] offset = dmem_addr - 32'h81000000;
    wire aligned_word = dmem_addr[1:0] == 2'b00 && dmem_width == 2'b00;
    wire is_priority = offset >= 32'h000004 && offset <= 32'h00003c && offset[1:0] == 2'b00;
    wire [3:0] priority_id = offset[5:2];
    wire is_pending = offset == 32'h001000;
    wire is_enable = offset == 32'h002000;
    wire is_threshold = offset == 32'h200000;
    wire is_claim = offset == 32'h200004;
    wire valid_offset = is_priority || is_pending || is_enable || is_threshold || is_claim;
    wire [15:0] pending = irq_sources & ~claimed;

    reg [3:0] best_id;
    reg [2:0] best_priority;

    always @(*) begin
        best_id = 4'd0;
        best_priority = 3'b0;
        for (i = 1; i < 16; i = i + 1) begin
            if (pending[i] && enable[i] && prio[i] > threshold && prio[i] > best_priority) begin
                best_id = i[3:0];
                best_priority = prio[i];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                prio[i] <= 3'b0;
            end
            enable <= 16'b0;
            threshold <= 3'b0;
            claimed <= 16'b0;
            dmem_rdata <= 32'b0;
        end else if (dmem_cs && aligned_word && valid_offset) begin
            if (dmem_we) begin
                dmem_rdata <= 32'b0;
                if (is_priority && priority_id != 4'd0) begin
                    prio[priority_id] <= dmem_wdata[2:0];
                end else if (is_enable) begin
                    enable <= dmem_wdata[15:0] & 16'hfffe;
                end else if (is_threshold) begin
                    threshold <= dmem_wdata[2:0];
                end else if (is_claim && dmem_wdata[3:0] != 4'd0) begin
                    claimed[dmem_wdata[3:0]] <= 1'b0;
                end
            end else begin
                if (is_priority) begin
                    dmem_rdata <= {29'b0, prio[priority_id]};
                end else if (is_pending) begin
                    dmem_rdata <= {16'b0, pending};
                end else if (is_enable) begin
                    dmem_rdata <= {16'b0, enable};
                end else if (is_threshold) begin
                    dmem_rdata <= {29'b0, threshold};
                end else if (is_claim) begin
                    dmem_rdata <= {28'b0, best_id};
                    if (best_id != 4'd0) begin
                        claimed[best_id] <= 1'b1;
                    end
                end
            end
        end else begin
            dmem_rdata <= 32'b0;
        end
    end

    assign dmem_ack = dmem_cs;
    assign dmem_fault = dmem_cs && (!aligned_word || !valid_offset || (dmem_we && is_pending));
    assign meip = best_id != 4'd0;
    assign dmem_irq = meip;
endmodule
