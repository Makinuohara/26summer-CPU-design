`timescale 1ns / 1ps

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
    output reg [3:0] mem_wstrb,
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

    localparam LINE_BITS = clog2(LINE_WORDS);
    localparam INDEX_BITS = clog2(CACHE_LINES);
    localparam TAG_BITS = 32 - INDEX_BITS - LINE_BITS - 2;

    localparam ST_IDLE = 3'd0;
    localparam ST_FILL_REQ = 3'd1;
    localparam ST_FILL_WAIT = 3'd2;
    localparam ST_FILL_RESP = 3'd3;
    localparam ST_WRITE_WAIT = 3'd4;

    reg [2:0] state;
    reg resp_valid;
    reg [31:0] resp_data;
    reg resp_fault;

    reg [31:0] req_addr_q;
    reg req_we_q;
    reg [31:0] req_wdata_q;
    reg [1:0] req_width_q;

    reg [INDEX_BITS-1:0] fill_index_q;
    reg [TAG_BITS-1:0] fill_tag_q;
    reg [LINE_BITS-1:0] fill_word_q;
    reg [31:0] fill_base_addr_q;
    reg [31:0] fill_buffer [0:LINE_WORDS-1];

    reg valid [0:CACHE_LINES-1];
    reg [TAG_BITS-1:0] tags [0:CACHE_LINES-1];
    reg [31:0] lines [0:CACHE_LINES-1][0:LINE_WORDS-1];

    integer i;
    integer j;

    wire [INDEX_BITS-1:0] req_index = addr[LINE_BITS+INDEX_BITS+1:LINE_BITS+2];
    wire [LINE_BITS-1:0] req_word = addr[LINE_BITS+1:2];
    wire [TAG_BITS-1:0] req_tag = addr[31:LINE_BITS+INDEX_BITS+2];
    wire req_hit = valid[req_index] && (tags[req_index] == req_tag);
    wire [31:0] req_hit_word = lines[req_index][req_word];
    wire [31:0] req_line_base = {addr[31:LINE_BITS+2], {LINE_BITS{1'b0}}, 2'b00};

    wire req_word_aligned = (addr[1:0] == 2'b00);
    wire req_half_aligned = (addr[0] == 1'b0);
    wire req_align_ok =
        (width == WIDTH_WORD && req_word_aligned) ||
        (width == WIDTH_HALF && req_half_aligned) ||
        (width == WIDTH_BYTE);
    wire req_width_ok = (width != 2'b11);

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

    task automatic calc_write_mask;
        input [31:0] addr_i;
        input [1:0] width_i;
        input [31:0] wdata_i;
        output [3:0] wstrb_o;
        output [31:0] wdata_o;
        begin
            wstrb_o = 4'b0000;
            wdata_o = 32'b0;
            case (width_i)
                WIDTH_WORD: begin
                    wstrb_o = 4'b1111;
                    wdata_o = wdata_i;
                end
                WIDTH_HALF: begin
                    if (addr_i[1] == 1'b0) begin
                        wstrb_o = 4'b0011;
                        wdata_o = {16'b0, wdata_i[15:0]};
                    end else begin
                        wstrb_o = 4'b1100;
                        wdata_o = {wdata_i[15:0], 16'b0};
                    end
                end
                WIDTH_BYTE: begin
                    case (addr_i[1:0])
                        2'b00: begin
                            wstrb_o = 4'b0001;
                            wdata_o = {24'b0, wdata_i[7:0]};
                        end
                        2'b01: begin
                            wstrb_o = 4'b0010;
                            wdata_o = {16'b0, wdata_i[7:0], 8'b0};
                        end
                        2'b10: begin
                            wstrb_o = 4'b0100;
                            wdata_o = {8'b0, wdata_i[7:0], 16'b0};
                        end
                        default: begin
                            wstrb_o = 4'b1000;
                            wdata_o = {wdata_i[7:0], 24'b0};
                        end
                    endcase
                end
                default: begin
                    wstrb_o = 4'b0000;
                    wdata_o = 32'b0;
                end
            endcase
        end
    endtask

    reg [3:0] write_mask_tmp;
    reg [31:0] write_data_tmp;

    always @(*) begin
        ack = resp_valid;
        rdata = resp_data;
        fault = resp_fault;
    end

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
            mem_wstrb <= 4'b0000;

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
                    mem_wstrb <= 4'b0000;

                    if (req) begin
                        if (!req_width_ok || !req_align_ok) begin
                            resp_valid <= 1'b1;
                            resp_fault <= 1'b1;
                            resp_data <= 32'b0;
                        end else if (we) begin
                            req_addr_q <= addr;
                            req_we_q <= 1'b1;
                            req_wdata_q <= wdata;
                            req_width_q <= width;

                            if (req_hit) begin
                                update_cache_word(req_index, req_word, addr, width, wdata);
                            end

                            calc_write_mask(addr, width, wdata, write_mask_tmp, write_data_tmp);
                            mem_req <= 1'b1;
                            mem_we <= 1'b1;
                            mem_addr <= addr;
                            mem_wdata <= write_data_tmp;
                            mem_wstrb <= write_mask_tmp;
                            state <= ST_WRITE_WAIT;
                        end else if (req_hit) begin
                            resp_valid <= 1'b1;
                            resp_fault <= 1'b0;
                            resp_data <= req_hit_word;
                        end else begin
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
                    mem_req <= 1'b1;
                    mem_we <= 1'b0;
                    mem_addr <= fill_base_addr_q + {{(32-LINE_BITS-2){1'b0}}, fill_word_q, 2'b00};
                    mem_wdata <= 32'b0;
                    mem_wstrb <= 4'b0000;
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
