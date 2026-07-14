`timescale 1ns / 1ps

// 直接映射、写直达 D-Cache。
//
// 该模块实例化在 pipeline_cpu_top 内部，只处理普通内存地址。
// MMIO 地址会在进入 cache 前被 CPU 近端译码逻辑分流并绕过 cache。
//
// 策略：
//   - 读命中：直接返回缓存字
//   - 读失效：从后端内存取回整条 cache line
//   - 写命中：更新缓存字，同时写后端内存
//   - 写失效：只写后端内存，不分配新缓存行
module cache #(
    parameter CACHE_LINES = 16,
    parameter LINE_WORDS = 4
) (
    input wire clk,
    input wire rst_n,

    input wire req,
    input wire [31:0] addr,
    input wire we,
    input wire [31:0] wdata,
    input wire [1:0] width,
    output reg ack,
    output reg [31:0] rdata,
    output reg fault,

    output reg mem_req,
    output reg mem_we,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [1:0] mem_width,
    input wire mem_ack,
    input wire [31:0] mem_rdata,
    input wire mem_fault
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

    localparam WIDTH_WORD = 2'b00;
    localparam WIDTH_HALF = 2'b01;
    localparam WIDTH_BYTE = 2'b10;

    // 地址划分：
    //   addr[1:0]                         字节偏移
    //   addr[LINE_BITS+1:2]               cache line 内的 word 下标
    //   addr[LINE_BITS+INDEX_BITS+1:...]  cache 行下标
    //   更高位                              tag
    localparam LINE_BITS = clog2(LINE_WORDS);
    localparam INDEX_BITS = clog2(CACHE_LINES);
    localparam TAG_BITS = 32 - INDEX_BITS - LINE_BITS - 2;

    // cache 填充时通过后端 req/ack 总线逐字读取一整行。
    // 写操作进入 ST_WRITE_WAIT，因为当前策略是写直达。
    localparam ST_IDLE = 3'd0;
    localparam ST_FILL_REQ = 3'd1;
    localparam ST_FILL_WAIT = 3'd2;
    localparam ST_FILL_RESP = 3'd3;
    localparam ST_WRITE_WAIT = 3'd4;

    // 单拍响应寄存器。ack/rdata/fault 由这些寄存器驱动，
    // 因此无论命中或失效，CPU 看到的都是统一的 req/ack 事务。
    reg [2:0] state;
    reg resp_valid;
    reg [31:0] resp_data;
    reg resp_fault;

    reg [31:0] req_addr_q;
    reg req_we_q;
    reg [31:0] req_wdata_q;
    reg [1:0] req_width_q;

    // 正在进行的 cache line 填充所需的锁存信息。
    reg [INDEX_BITS-1:0] fill_index_q;
    reg [TAG_BITS-1:0] fill_tag_q;
    reg [LINE_BITS-1:0] fill_word_q;
    reg [31:0] fill_base_addr_q;
    reg [31:0] fill_buffer [0:LINE_WORDS-1];

    // 直接映射存储结构：每个 cache index 对应一个 valid 位、
    // 一个 tag，以及 LINE_WORDS 个 32 位数据字。
    reg valid [0:CACHE_LINES-1];
    reg [TAG_BITS-1:0] tags [0:CACHE_LINES-1];
    reg [31:0] lines [0:CACHE_LINES-1][0:LINE_WORDS-1];

    integer i;
    integer j;

    wire [INDEX_BITS-1:0] req_index = addr[LINE_BITS+INDEX_BITS+1:LINE_BITS+2];
    wire [LINE_BITS-1:0] req_word = addr[LINE_BITS+1:2];
    wire [TAG_BITS-1:0] req_tag = addr[31:LINE_BITS+INDEX_BITS+2];
    // 命中判断在 IDLE 阶段用组合逻辑完成。
    // 离开 IDLE 前，状态机会锁存失效填充或写操作所需的请求信息。
    wire req_hit = valid[req_index] && (tags[req_index] == req_tag);
    wire [31:0] req_hit_word = lines[req_index][req_word];
    wire [31:0] req_line_base = {addr[31:LINE_BITS+2], {LINE_BITS{1'b0}}, 2'b00};

    // cache 接受 word/half/byte 三种访问宽度，
    // 但未对齐的 word/half 访问会返回 fault。
    // load 的符号扩展或零扩展由 CPU 流水线负责。
    wire req_word_aligned = (addr[1:0] == 2'b00);
    wire req_half_aligned = (addr[0] == 1'b0);
    wire req_align_ok =
        (width == WIDTH_WORD && req_word_aligned) ||
        (width == WIDTH_HALF && req_half_aligned) ||
        (width == WIDTH_BYTE);
    wire req_width_ok = (width != 2'b11);

    // 将 store 数据合并进已缓存的 word。
    // 该任务只用于写命中；写失效采用不分配策略，因此不会更新 cache line。
    task automatic update_cache_word;
        input [INDEX_BITS-1:0] index_i;
        input [LINE_BITS-1:0] word_i;
        input [31:0] addr_i;
        input [1:0] width_i;
        input [31:0] wdata_i;
        reg [31:0] current_word;
        begin
            current_word = lines[index_i][word_i];
            case (width_i)
                WIDTH_WORD: lines[index_i][word_i] <= wdata_i;
                WIDTH_HALF: begin
                    if (addr_i[1] == 1'b0) begin
                        lines[index_i][word_i] <= {current_word[31:16], wdata_i[15:0]};
                    end else begin
                        lines[index_i][word_i] <= {wdata_i[15:0], current_word[15:0]};
                    end
                end
                WIDTH_BYTE: begin
                    case (addr_i[1:0])
                        2'b00: lines[index_i][word_i] <= {current_word[31:8], wdata_i[7:0]};
                        2'b01: lines[index_i][word_i] <= {current_word[31:16], wdata_i[7:0], current_word[7:0]};
                        2'b10: lines[index_i][word_i] <= {current_word[31:24], wdata_i[7:0], current_word[15:0]};
                        default: lines[index_i][word_i] <= {wdata_i[7:0], current_word[23:0]};
                    endcase
                end
                default: lines[index_i][word_i] <= current_word;
            endcase
        end
    endtask

    always @(*) begin
        ack = resp_valid;
        rdata = resp_data;
        fault = resp_fault;
    end

    // cache 主控制器：
    //   ST_IDLE       接收 CPU 请求，并判断命中/失效/写操作
    //   ST_FILL_REQ   向后端发起当前填充 word 的读请求
    //   ST_FILL_WAIT  等待后端响应
    //   ST_FILL_RESP  安装整条 cache line，并返回请求字
    //   ST_WRITE_WAIT 等待写直达后端完成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            resp_valid <= 1'b0;
            resp_data <= 32'b0;
            resp_fault <= 1'b0;

            mem_req <= 1'b0;
            mem_we <= 1'b0;
            mem_addr <= 32'b0;
            mem_wdata <= 32'b0;
            mem_width <= WIDTH_WORD;

            req_addr_q <= 32'b0;
            req_we_q <= 1'b0;
            req_wdata_q <= 32'b0;
            req_width_q <= WIDTH_WORD;
            fill_index_q <= {INDEX_BITS{1'b0}};
            fill_tag_q <= {TAG_BITS{1'b0}};
            fill_word_q <= {LINE_BITS{1'b0}};
            fill_base_addr_q <= 32'b0;

            for (i = 0; i < CACHE_LINES; i = i + 1) begin
                valid[i] <= 1'b0;
                tags[i] <= {TAG_BITS{1'b0}};
                for (j = 0; j < LINE_WORDS; j = j + 1) begin
                    lines[i][j] <= 32'b0;
                end
            end
        end else begin
            if (resp_valid) begin
                resp_valid <= 1'b0;
            end

            case (state)
                ST_IDLE: begin
                    mem_req <= 1'b0;
                    mem_we <= 1'b0;
                    mem_addr <= 32'b0;
                    mem_wdata <= 32'b0;
                    mem_width <= WIDTH_WORD;

                    if (req && !resp_valid) begin
                        if (!req_width_ok || !req_align_ok) begin
                            // 宽度非法或地址未对齐时立即返回 fault，
                            // 不再发起后端内存事务。
                            resp_valid <= 1'b1;
                            resp_fault <= 1'b1;
                            resp_data <= 32'b0;
                        end else if (we) begin
                            // 写直达路径。写命中时同时更新缓存副本；
                            // 写失效时表现为 write-no-allocate。
                            req_addr_q <= addr;
                            req_we_q <= 1'b1;
                            req_wdata_q <= wdata;
                            req_width_q <= width;

                            if (req_hit) begin
                                update_cache_word(req_index, req_word, addr, width, wdata);
                            end

                            mem_req <= 1'b1;
                            mem_we <= 1'b1;
                            mem_addr <= addr;
                            mem_wdata <= wdata;
                            mem_width <= width;
                            state <= ST_WRITE_WAIT;
                        end else if (req_hit) begin
                            // 读命中：直接返回选中的 word，不访问后端内存。
                            resp_valid <= 1'b1;
                            resp_fault <= 1'b0;
                            resp_data <= req_hit_word;
                        end else begin
                            // 读失效：记录请求信息，并开始从后端内存取回整行。
                            req_addr_q <= addr;
                            req_we_q <= 1'b0;
                            req_width_q <= width;
                            fill_index_q <= req_index;
                            fill_tag_q <= req_tag;
                            fill_word_q <= {LINE_BITS{1'b0}};
                            fill_base_addr_q <= req_line_base;
                            state <= ST_FILL_REQ;
                        end
                    end
                end

                ST_FILL_REQ: begin
                    // 从对齐后的 cache line 基地址开始，请求当前 word。
                    mem_req <= 1'b1;
                    mem_we <= 1'b0;
                    mem_addr <= fill_base_addr_q + {{(32-LINE_BITS-2){1'b0}}, fill_word_q, 2'b00};
                    mem_wdata <= 32'b0;
                    mem_width <= WIDTH_WORD;
                    state <= ST_FILL_WAIT;
                end

                ST_FILL_WAIT: begin
                    if (mem_ack) begin
                        mem_req <= 1'b0;
                        if (mem_fault) begin
                            resp_valid <= 1'b1;
                            resp_fault <= 1'b1;
                            resp_data <= 32'b0;
                            state <= ST_IDLE;
                        end else begin
                            // 将返回的 word 暂存到填充缓冲区。
                            // 只有整行全部取回后才安装到 cache，避免出现部分有效行。
                            fill_buffer[fill_word_q] <= mem_rdata;
                            if (fill_word_q == LINE_WORDS - 1) begin
                                state <= ST_FILL_RESP;
                            end else begin
                                fill_word_q <= fill_word_q + 1'b1;
                                state <= ST_FILL_REQ;
                            end
                        end
                    end
                end

                ST_FILL_RESP: begin
                    // 填充完成：安装 tag/data，置 valid，
                    // 并把最初请求的 word 返回给 CPU。
                    valid[fill_index_q] <= 1'b1;
                    tags[fill_index_q] <= fill_tag_q;
                    for (j = 0; j < LINE_WORDS; j = j + 1) begin
                        lines[fill_index_q][j] <= fill_buffer[j];
                    end
                    resp_valid <= 1'b1;
                    resp_fault <= 1'b0;
                    resp_data <= fill_buffer[req_addr_q[LINE_BITS+1:2]];
                    state <= ST_IDLE;
                end

                ST_WRITE_WAIT: begin
                    // 后端内存确认写直达事务后，store 才算完成。
                    if (mem_ack) begin
                        mem_req <= 1'b0;
                        resp_valid <= 1'b1;
                        resp_fault <= mem_fault;
                        resp_data <= 32'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
