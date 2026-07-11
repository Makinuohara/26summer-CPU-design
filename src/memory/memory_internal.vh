`ifndef MEMORY_INTERNAL_VH
`define MEMORY_INTERNAL_VH

module memory_backend_core #(
    parameter ADDR_WIDTH = 12,
    parameter MEM_LATENCY = 1,
    parameter INIT_FILE = ""
) (
    input wire clk,
    input wire rst_n,
    input wire req,
    input wire we,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0] wstrb,
    output wire ack,
    output wire [31:0] rdata,
    output wire fault
);
    function integer clog2;
        input integer value;
        integer tmp;
        begin
            tmp = value - 1;
            clog2 = 0;
            while (tmp > 0) begin
                tmp = tmp >> 1;
                clog2 = clog2 + 1;
            end
        end
    endfunction

    localparam DEPTH = 1 << ADDR_WIDTH;
    localparam COUNT_WIDTH = (MEM_LATENCY > 0) ? clog2(MEM_LATENCY + 1) : 1;

    reg [31:0] mem [0:DEPTH-1];
    reg busy;
    reg we_q;
    reg [31:0] addr_q;
    reg [31:0] wdata_q;
    reg [3:0] wstrb_q;
    reg [COUNT_WIDTH-1:0] wait_q;
    reg resp_valid;
    reg [31:0] resp_data;
    reg resp_fault;
    integer i;

    wire in_range_now = (addr[31:ADDR_WIDTH+2] == {30-ADDR_WIDTH{1'b0}});
    wire in_range_q = (addr_q[31:ADDR_WIDTH+2] == {30-ADDR_WIDTH{1'b0}});
    wire [ADDR_WIDTH-1:0] index_now = addr[ADDR_WIDTH+1:2];
    wire [ADDR_WIDTH-1:0] index_q = addr_q[ADDR_WIDTH+1:2];

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'b0;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Control path — async reset on control regs only
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            we_q <= 1'b0;
            addr_q <= 32'b0;
            wdata_q <= 32'b0;
            wstrb_q <= 4'b0000;
            wait_q <= {COUNT_WIDTH{1'b0}};
            resp_valid <= 1'b0;
            resp_fault <= 1'b0;
        end else begin
            if (resp_valid) begin
                resp_valid <= 1'b0;
            end

            if (!busy) begin
                if (!resp_valid && req) begin
                    if (MEM_LATENCY == 0) begin
                        resp_valid <= 1'b1;
                        resp_fault <= !in_range_now;
                    end else begin
                        busy <= 1'b1;
                        we_q <= we;
                        addr_q <= addr;
                        wdata_q <= wdata;
                        wstrb_q <= wstrb;
                        wait_q <= MEM_LATENCY - 1;
                    end
                end
            end else if (wait_q != 0) begin
                wait_q <= wait_q - 1'b1;
            end else begin
                busy <= 1'b0;
                resp_valid <= 1'b1;
                resp_fault <= !in_range_q;
            end
        end
    end

    // Memory read/write path — pure synchronous, no reset (allows BRAM inference)
    always @(posedge clk) begin
        if (MEM_LATENCY == 0) begin
            if (!busy && resp_valid == 1'b0 && req) begin
                resp_data <= in_range_now ? mem[index_now] : 32'b0;
                if (we && in_range_now) begin
                    if (wstrb[0]) mem[index_now][7:0] <= wdata[7:0];
                    if (wstrb[1]) mem[index_now][15:8] <= wdata[15:8];
                    if (wstrb[2]) mem[index_now][23:16] <= wdata[23:16];
                    if (wstrb[3]) mem[index_now][31:24] <= wdata[31:24];
                end
            end
        end else begin
            if (busy && wait_q == 0) begin
                resp_data <= in_range_q ? mem[index_q] : 32'b0;
                if (we_q && in_range_q) begin
                    if (wstrb_q[0]) mem[index_q][7:0] <= wdata_q[7:0];
                    if (wstrb_q[1]) mem[index_q][15:8] <= wdata_q[15:8];
                    if (wstrb_q[2]) mem[index_q][23:16] <= wdata_q[23:16];
                    if (wstrb_q[3]) mem[index_q][31:24] <= wdata_q[31:24];
                end
            end
        end
    end

    assign ack = resp_valid;
    assign rdata = resp_data;
    assign fault = resp_fault;
endmodule

`endif
