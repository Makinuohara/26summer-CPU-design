`timescale 1ns / 1ps

module pipeline_cpu_top (
    input wire clk,
    input wire rst_n,

    output wire imem_req,
    output wire [31:0] imem_addr,
    input wire imem_ack,
    input wire [31:0] imem_data,

    output wire dmem_req,
    output wire [31:0] dmem_addr,
    output wire dmem_we,
    output wire [31:0] dmem_wdata,
    output wire [1:0] dmem_width,
    input wire dmem_ack,
    input wire [31:0] dmem_rdata,
    input wire dmem_fault,

    input wire meip,
    input wire mtip,
    input wire msip,

    output wire [31:0] debug_pc,
    output wire [31:0] debug_cycle,
    output wire [31:0] debug_instret,
    output wire [31:0] debug_stall,
    output wire [31:0] debug_flush,
    output wire [31:0] debug_x5
);
    localparam OPCODE_OP     = 7'b0110011;
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;

    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_SLL = 4'd5;
    localparam ALU_SRL = 4'd6;
    localparam ALU_SRA = 4'd7;
    localparam ALU_SLT = 4'd8;
    localparam ALU_SLTU = 4'd9;

    localparam WB_ALU = 2'd0;
    localparam WB_MEM = 2'd1;
    localparam WB_PC4 = 2'd2;
    localparam WB_IMM = 2'd3;

    localparam BR_NONE = 3'd0;
    localparam BR_BEQ  = 3'd1;
    localparam BR_BNE  = 3'd2;
    localparam BR_BLT  = 3'd3;
    localparam BR_BGE  = 3'd4;
    localparam BR_BLTU = 3'd5;
    localparam BR_BGEU = 3'd6;

    reg [31:0] pc;

    reg if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_pc4;
    reg [31:0] if_id_instr;

    reg id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_pc4;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0] id_ex_rs1;
    reg [4:0] id_ex_rs2;
    reg [4:0] id_ex_rd;
    reg id_ex_reg_write;
    reg id_ex_mem_read;
    reg id_ex_mem_write;
    reg [1:0] id_ex_mem_width;
    reg id_ex_alu_src_imm;
    reg id_ex_alu_src_pc;
    reg [3:0] id_ex_alu_ctrl;
    reg [1:0] id_ex_wb_sel;
    reg [2:0] id_ex_branch_type;
    reg id_ex_jump;
    reg id_ex_jalr;

    reg ex_mem_valid;
    reg [31:0] ex_mem_pc4;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [31:0] ex_mem_imm;
    reg [4:0] ex_mem_rd;
    reg ex_mem_reg_write;
    reg ex_mem_mem_read;
    reg ex_mem_mem_write;
    reg [1:0] ex_mem_mem_width;
    reg [1:0] ex_mem_wb_sel;
    reg ex_mem_fault;

    reg mem_wb_valid;
    reg [31:0] mem_wb_pc4;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_imm;
    reg [4:0] mem_wb_rd;
    reg mem_wb_reg_write;
    reg [1:0] mem_wb_wb_sel;
    reg mem_wb_fault;

    wire [6:0] if_id_opcode = if_id_instr[6:0];
    wire [4:0] if_id_rd = if_id_instr[11:7];
    wire [2:0] if_id_funct3 = if_id_instr[14:12];
    wire [4:0] if_id_rs1 = if_id_instr[19:15];
    wire [4:0] if_id_rs2 = if_id_instr[24:20];
    wire [6:0] if_id_funct7 = if_id_instr[31:25];

    wire [31:0] wb_data =
        (mem_wb_wb_sel == WB_MEM) ? mem_wb_mem_data :
        (mem_wb_wb_sel == WB_PC4) ? mem_wb_pc4 :
        (mem_wb_wb_sel == WB_IMM) ? mem_wb_imm :
                                    mem_wb_alu_result;
    wire [31:0] ex_mem_write_data =
        (ex_mem_wb_sel == WB_PC4) ? ex_mem_pc4 :
        (ex_mem_wb_sel == WB_IMM) ? ex_mem_imm :
                                    ex_mem_alu_result;

    wire trap_pending = meip | mtip | msip;
    wire wb_write = mem_wb_valid && mem_wb_reg_write && !mem_wb_fault && !trap_pending;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    pipeline_regfile u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write(wb_write),
        .rs1(if_id_rs1),
        .rs2(if_id_rs2),
        .rd(mem_wb_rd),
        .write_data(wb_data),
        .read_data1(rs1_data),
        .read_data2(rs2_data),
        .debug_x5(debug_x5)
    );

    wire dec_reg_write;
    wire dec_mem_read;
    wire dec_mem_write;
    wire [1:0] dec_mem_width;
    wire dec_alu_src_imm;
    wire dec_alu_src_pc;
    wire [3:0] dec_alu_ctrl;
    wire [1:0] dec_wb_sel;
    wire [2:0] dec_branch_type;
    wire dec_jump;
    wire dec_jalr;

    pipeline_control_unit u_control (
        .opcode(if_id_opcode),
        .funct3(if_id_funct3),
        .funct7(if_id_funct7),
        .reg_write(dec_reg_write),
        .mem_read(dec_mem_read),
        .mem_write(dec_mem_write),
        .mem_width(dec_mem_width),
        .alu_src_imm(dec_alu_src_imm),
        .alu_src_pc(dec_alu_src_pc),
        .alu_ctrl(dec_alu_ctrl),
        .wb_sel(dec_wb_sel),
        .branch_type(dec_branch_type),
        .jump(dec_jump),
        .jalr(dec_jalr)
    );

    wire [31:0] dec_imm;

    pipeline_imm_gen u_imm_gen (
        .instr(if_id_instr),
        .imm(dec_imm)
    );

    wire load_use_stall;

    pipeline_hazard_unit u_hazard (
        .if_id_valid(if_id_valid),
        .id_ex_valid(id_ex_valid),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd(id_ex_rd),
        .if_id_rs1(if_id_rs1),
        .if_id_rs2(if_id_rs2),
        .if_id_opcode(if_id_opcode),
        .load_use_stall(load_use_stall)
    );

    wire mem_active = ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write);
    wire imem_wait = imem_req && !imem_ack;
    wire dmem_wait = mem_active && !dmem_ack;
    wire global_stall = imem_wait || dmem_wait || load_use_stall;

    wire [31:0] fwd_rs1;
    wire [31:0] fwd_rs2;

    pipeline_forwarding_unit u_forwarding (
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .id_ex_rs1_data(id_ex_rs1_data),
        .id_ex_rs2_data(id_ex_rs2_data),
        .ex_mem_valid(ex_mem_valid),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_write_data(ex_mem_write_data),
        .mem_wb_valid(mem_wb_valid),
        .mem_wb_reg_write(mem_wb_reg_write),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_write_data(wb_data),
        .fwd_rs1(fwd_rs1),
        .fwd_rs2(fwd_rs2)
    );

    wire [31:0] alu_a = id_ex_alu_src_pc ? id_ex_pc : fwd_rs1;
    wire [31:0] alu_b = id_ex_alu_src_imm ? id_ex_imm : fwd_rs2;
    wire [31:0] alu_result;

    pipeline_alu u_alu (
        .a(alu_a),
        .b(alu_b),
        .alu_ctrl(id_ex_alu_ctrl),
        .result(alu_result)
    );

    wire branch_taken = id_ex_valid && (
        (id_ex_branch_type == BR_BEQ  && (fwd_rs1 == fwd_rs2)) ||
        (id_ex_branch_type == BR_BNE  && (fwd_rs1 != fwd_rs2)) ||
        (id_ex_branch_type == BR_BLT  && ($signed(fwd_rs1) < $signed(fwd_rs2))) ||
        (id_ex_branch_type == BR_BGE  && ($signed(fwd_rs1) >= $signed(fwd_rs2))) ||
        (id_ex_branch_type == BR_BLTU && (fwd_rs1 < fwd_rs2)) ||
        (id_ex_branch_type == BR_BGEU && (fwd_rs1 >= fwd_rs2))
    );
    wire jump_taken = id_ex_valid && id_ex_jump;
    wire redirect = branch_taken || jump_taken;
    wire [31:0] branch_target = id_ex_pc + id_ex_imm;
    wire [31:0] jalr_target = (fwd_rs1 + id_ex_imm) & 32'hffff_fffe;
    wire [31:0] redirect_pc = id_ex_jalr ? jalr_target : branch_target;

    assign imem_req = rst_n;
    assign imem_addr = pc;

    assign dmem_req = mem_active;
    assign dmem_addr = ex_mem_alu_result;
    assign dmem_we = ex_mem_mem_write;
    assign dmem_wdata = ex_mem_store_data;
    assign dmem_width = ex_mem_mem_width;

    assign debug_pc = pc;

    pipeline_perf_counter u_perf (
        .clk(clk),
        .rst_n(rst_n),
        .stall(global_stall),
        .flush(redirect && !global_stall),
        .instret(mem_wb_valid && !mem_wb_fault && !trap_pending),
        .cycle_count(debug_cycle),
        .instret_count(debug_instret),
        .stall_count(debug_stall),
        .flush_count(debug_flush)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'b0;
            if_id_valid <= 1'b0;
            if_id_pc <= 32'b0;
            if_id_pc4 <= 32'b0;
            if_id_instr <= 32'h00000013;

            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'b0;
            id_ex_pc4 <= 32'b0;
            id_ex_rs1_data <= 32'b0;
            id_ex_rs2_data <= 32'b0;
            id_ex_imm <= 32'b0;
            id_ex_rs1 <= 5'b0;
            id_ex_rs2 <= 5'b0;
            id_ex_rd <= 5'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_width <= 2'b00;
            id_ex_alu_src_imm <= 1'b0;
            id_ex_alu_src_pc <= 1'b0;
            id_ex_alu_ctrl <= ALU_ADD;
            id_ex_wb_sel <= WB_ALU;
            id_ex_branch_type <= BR_NONE;
            id_ex_jump <= 1'b0;
            id_ex_jalr <= 1'b0;

            ex_mem_valid <= 1'b0;
            ex_mem_pc4 <= 32'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_imm <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_width <= 2'b00;
            ex_mem_wb_sel <= WB_ALU;
            ex_mem_fault <= 1'b0;

            mem_wb_valid <= 1'b0;
            mem_wb_pc4 <= 32'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_imm <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_wb_sel <= WB_ALU;
            mem_wb_fault <= 1'b0;
        end else if (!global_stall) begin
            if (redirect) begin
                pc <= redirect_pc;
                if_id_valid <= 1'b0;
                id_ex_valid <= 1'b0;
            end else if (imem_ack) begin
                pc <= pc + 32'd4;
                if_id_valid <= 1'b1;
                if_id_pc <= pc;
                if_id_pc4 <= pc + 32'd4;
                if_id_instr <= imem_data;

                id_ex_valid <= if_id_valid;
                id_ex_pc <= if_id_pc;
                id_ex_pc4 <= if_id_pc4;
                id_ex_rs1_data <= rs1_data;
                id_ex_rs2_data <= rs2_data;
                id_ex_imm <= dec_imm;
                id_ex_rs1 <= if_id_rs1;
                id_ex_rs2 <= if_id_rs2;
                id_ex_rd <= if_id_rd;
                id_ex_reg_write <= dec_reg_write;
                id_ex_mem_read <= dec_mem_read;
                id_ex_mem_write <= dec_mem_write;
                id_ex_mem_width <= dec_mem_width;
                id_ex_alu_src_imm <= dec_alu_src_imm;
                id_ex_alu_src_pc <= dec_alu_src_pc;
                id_ex_alu_ctrl <= dec_alu_ctrl;
                id_ex_wb_sel <= dec_wb_sel;
                id_ex_branch_type <= dec_branch_type;
                id_ex_jump <= dec_jump;
                id_ex_jalr <= dec_jalr;
            end

            ex_mem_valid <= id_ex_valid;
            ex_mem_pc4 <= id_ex_pc4;
            ex_mem_alu_result <= alu_result;
            ex_mem_store_data <= fwd_rs2;
            ex_mem_imm <= id_ex_imm;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_width <= id_ex_mem_width;
            ex_mem_wb_sel <= id_ex_wb_sel;
            ex_mem_fault <= 1'b0;

            mem_wb_valid <= ex_mem_valid;
            mem_wb_pc4 <= ex_mem_pc4;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= dmem_rdata;
            mem_wb_imm <= ex_mem_imm;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_wb_sel <= ex_mem_wb_sel;
            mem_wb_fault <= ex_mem_fault || (mem_active && dmem_fault);
        end else if (load_use_stall && !imem_wait && !dmem_wait) begin
            id_ex_valid <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;

            ex_mem_valid <= id_ex_valid;
            ex_mem_pc4 <= id_ex_pc4;
            ex_mem_alu_result <= alu_result;
            ex_mem_store_data <= fwd_rs2;
            ex_mem_imm <= id_ex_imm;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_width <= id_ex_mem_width;
            ex_mem_wb_sel <= id_ex_wb_sel;
            ex_mem_fault <= 1'b0;

            mem_wb_valid <= ex_mem_valid;
            mem_wb_pc4 <= ex_mem_pc4;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= dmem_rdata;
            mem_wb_imm <= ex_mem_imm;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_wb_sel <= ex_mem_wb_sel;
            mem_wb_fault <= ex_mem_fault || (mem_active && dmem_fault);
        end
    end

endmodule
