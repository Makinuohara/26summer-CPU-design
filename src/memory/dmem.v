// ============================================================
// 文件名: dmem.v
// 功能: 数据存储器 (读写)
// ============================================================

module dmem #(
    parameter DMEM_DEPTH = 4096
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     read_en,
    input  wire                     write_en,
    input  wire [31:0]              addr,
    input  wire [31:0]              write_data,
    output wire [31:0]              read_data,
    output wire                     ready
);

    wire [31:0] ram_read_data_internal;

    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) u_ram (
        .clk        (clk),
        .rst_n      (rst_n),
        .read_en    (read_en),
        .write_en   (write_en),
        .addr       (addr),
        .write_data (write_data),
        .read_data  (ram_read_data_internal),
        .ready      (ready)
    );

    assign read_data = ram_read_data_internal;

endmodule