// ============================================================
// 文件名: cache.v
// 功能: 直接映射Cache，8行，每行1字
// 说明: 简化版，使用组合逻辑判断命中，适合仿真验证
// ============================================================

module cache #(
    parameter NUM_LINES = 8,
    parameter INDEX_WIDTH = 3
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     read_en,
    input  wire                     write_en,
    input  wire [31:0]              addr,
    input  wire [31:0]              write_data,
    output reg  [31:0]              read_data,
    output wire                     ready,
    output reg                      hit,
    output reg                      miss,
    output reg  [31:0]              hit_count,
    output reg  [31:0]              miss_count
);

    // ============================================================
    // Cache存储阵列
    // ============================================================
    reg [31:0] cache_data [0:NUM_LINES-1];
    reg [31:0] cache_tag  [0:NUM_LINES-1];
    reg        cache_valid[0:NUM_LINES-1];

    // ============================================================
    // 地址分解
    // ============================================================
    wire [INDEX_WIDTH-1:0] index = addr[INDEX_WIDTH+1:2];
    wire [31:0] tag = addr[31:INDEX_WIDTH+1];

    // ============================================================
    // 命中判断 (组合逻辑)
    // ============================================================
    wire hit_internal = cache_valid[index] && (cache_tag[index] == tag);

    // ============================================================
    // 初始化
    // ============================================================
    integer i;
    initial begin
        for (i = 0; i < NUM_LINES; i = i + 1) begin
            cache_data[i] = 32'b0;
            cache_tag[i] = 32'b0;
            cache_valid[i] = 1'b0;
        end
        hit_count = 32'b0;
        miss_count = 32'b0;
        hit = 1'b0;
        miss = 1'b0;
        read_data = 32'b0;
    end

    // ============================================================
    // 主逻辑
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位Cache
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                cache_valid[i] <= 1'b0;
            end
            hit_count <= 32'b0;
            miss_count <= 32'b0;
            hit <= 1'b0;
            miss <= 1'b0;
            read_data <= 32'b0;
            
        end else begin
            // 默认值
            hit <= 1'b0;
            miss <= 1'b0;
            
            if (read_en || write_en) begin
                if (hit_internal) begin
                    // =====================================
                    // Cache Hit
                    // =====================================
                    hit <= 1'b1;
                    hit_count <= hit_count + 1;
                    
                    if (read_en) begin
                        read_data <= cache_data[index];
                    end
                    if (write_en) begin
                        cache_data[index] <= write_data;
                    end
                    
                end else begin
                    // =====================================
                    // Cache Miss
                    // =====================================
                    miss <= 1'b1;
                    miss_count <= miss_count + 1;
                    
                    // 从内存读取到Cache (这里简化，使用一个默认值)
                    // 在真实系统中，这里会从下层内存读取
                    if (read_en) begin
                        // 读miss：填充Cache，但read_data保持旧值
                        // 注意：实际应该在下一个周期返回数据
                        cache_data[index] <= 32'hAAAAAAAA;  // 默认填充值
                        cache_tag[index] <= tag;
                        cache_valid[index] <= 1'b1;
                        read_data <= 32'hAAAAAAAA;
                    end
                    if (write_en) begin
                        // 写miss：直接写入Cache
                        cache_data[index] <= write_data;
                        cache_tag[index] <= tag;
                        cache_valid[index] <= 1'b1;
                    end
                end
            end
        end
    end

    // ============================================================
    // 就绪信号
    // ============================================================
    assign ready = 1'b1;

endmodule