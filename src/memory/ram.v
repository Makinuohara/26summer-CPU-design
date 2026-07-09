// ============================================================
// 文件名: ram.v
// 功能: 统一RAM接口 - 使用 >> 运算符确保地址译码稳定
// ============================================================

module ram #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     read_en,
    input  wire                     write_en,
    input  wire [31:0]              addr,
    input  wire [DATA_WIDTH-1:0]    write_data,
    output reg  [DATA_WIDTH-1:0]    read_data,
    output wire                     ready
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    wire [ADDR_WIDTH-1:0] index = addr >> 2;   // ← 关键修复！

    integer i;
    initial begin
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            mem[i] = 0;
        end
    end

    always @(posedge clk) begin
        if (write_en) begin
            mem[index] <= write_data;
            $display("[RAM] WRITE addr=%h, index=%0d, data=%h", addr, index, write_data);
        end
    end

    always @(*) begin
        if (read_en) begin
            read_data = mem[index];
            $display("[RAM] READ addr=%h, index=%0d, data=%h", addr, index, read_data);
        end else begin
            read_data = 32'b0;
        end
    end

    assign ready = 1'b1;

endmodule