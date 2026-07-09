// ============================================================
// 文件名: imem.v
// 功能: 指令存储器 (只读) - 使用显式连线
// ============================================================

module imem #(
    parameter IMEM_DEPTH = 4096
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     read_en,
    input  wire [31:0]              addr,
    output wire [31:0]              instr_out,
    output wire                     ready
);

    // 内部线连接 RAM 的读数据
    wire [31:0] ram_read_data;

    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) u_ram (
        .clk        (clk),
        .rst_n      (rst_n),
        .read_en    (read_en),
        .write_en   (1'b0),
        .addr       (addr),
        .write_data (32'b0),
        .read_data  (ram_read_data),
        .ready      (ready)
    );

    // 显式连接输出
    assign instr_out = ram_read_data;

endmodule