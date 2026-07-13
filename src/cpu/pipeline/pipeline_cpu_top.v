`timescale 1ns / 1ps

module pipeline_cpu_top #(
    parameter DCACHE_LINES = 16,
    parameter DCACHE_LINE_WORDS = 4
) (
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
    localparam ALU_ADD = 4'd0;

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
    reg [31:0] id_ex_csr_rdata;
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
    reg id_ex_csr_en;
    reg [1:0] id_ex_csr_op;
    reg id_ex_csr_use_imm;
    reg [11:0] id_ex_csr_addr;
    reg id_ex_mret;

    reg ex_mem_valid;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_pc4;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [31:0] ex_mem_imm;
    reg [31:0] ex_mem_csr_wdata;
    reg [4:0] ex_mem_rd;
    reg ex_mem_reg_write;
    reg ex_mem_mem_read;
    reg ex_mem_mem_write;
    reg [1:0] ex_mem_mem_width;
    reg [1:0] ex_mem_wb_sel;
    reg ex_mem_fault;
    reg ex_mem_csr_en;
    reg [1:0] ex_mem_csr_op;
    reg [11:0] ex_mem_csr_addr;

    reg mem_wb_valid;
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_pc4;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_imm;
    reg [31:0] mem_wb_csr_wdata;
    reg [4:0] mem_wb_rd;
    reg mem_wb_reg_write;
    reg [1:0] mem_wb_wb_sel;
    reg mem_wb_fault;
    reg mem_wb_csr_en;
    reg [1:0] mem_wb_csr_op;
    reg [11:0] mem_wb_csr_addr;

    reg interrupt_drain_active;
    reg [31:0] interrupt_resume_pc;
    reg discard_imem_resp;

    wire [6:0] if_id_opcode = if_id_instr[6:0];
    wire [4:0] if_id_rd = if_id_instr[11:7];
    wire [2:0] if_id_funct3 = if_id_instr[14:12];
    wire [4:0] if_id_rs1 = if_id_instr[19:15];
    wire [4:0] if_id_rs2 = if_id_instr[24:20];
    wire [6:0] if_id_funct7 = if_id_instr[31:25];
    wire [11:0] if_id_csr_addr = if_id_instr[31:20];

    wire [31:0] wb_data =
        (mem_wb_wb_sel == WB_MEM) ? mem_wb_mem_data :
        (mem_wb_wb_sel == WB_PC4) ? mem_wb_pc4 :
        (mem_wb_wb_sel == WB_IMM) ? mem_wb_imm :
                                    mem_wb_alu_result;

    wire [31:0] ex_mem_write_data =
        (ex_mem_wb_sel == WB_PC4) ? ex_mem_pc4 :
        (ex_mem_wb_sel == WB_IMM) ? ex_mem_imm :
                                    ex_mem_alu_result;

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire wb_write = mem_wb_valid && mem_wb_reg_write && !mem_wb_fault;

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
    wire dec_csr_en;
    wire [1:0] dec_csr_op;
    wire dec_csr_use_imm;
    wire dec_mret;

    pipeline_control_unit u_control (
        .opcode(if_id_opcode),
        .funct3(if_id_funct3),
        .funct7(if_id_funct7),
        .instr(if_id_instr),
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
        .jalr(dec_jalr),
        .csr_en(dec_csr_en),
        .csr_op(dec_csr_op),
        .csr_use_imm(dec_csr_use_imm),
        .mret(dec_mret)
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
        .if_id_funct3(if_id_funct3),
        .load_use_stall(load_use_stall)
    );

    wire mem_active = ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write);
    wire [31:0] core_dmem_addr = ex_mem_alu_result;
    wire core_dmem_req = mem_active;
    wire core_dmem_cached = core_dmem_addr < 32'h0800_0000;
    wire [31:0] cache_dmem_addr;
    wire cache_dmem_req;
    wire cache_dmem_we;
    wire [31:0] cache_dmem_wdata;
    wire [1:0] cache_dmem_width;
    wire cache_ack;
    wire [31:0] cache_rdata;
    wire cache_fault;
    wire dmem_rsp_ack = core_dmem_cached ? cache_ack : dmem_ack;
    wire [31:0] dmem_rsp_rdata = core_dmem_cached ? cache_rdata : dmem_rdata;
    wire dmem_rsp_fault = core_dmem_cached ? cache_fault : dmem_fault;
    wire imem_wait = imem_req && !imem_ack;
    wire dmem_wait = mem_active && !dmem_rsp_ack;
    // Front-end fetch wait should not freeze the older pipeline stages. Otherwise
    // an instruction already sitting in IF/ID only moves forward when the *next*
    // instruction arrives, and older EX/MEM/WB stages can be replayed or delayed.
    wire pipeline_stall = dmem_wait || load_use_stall;
    wire perf_stall = imem_wait || pipeline_stall;

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

    wire [31:0] csr_read_data;
    wire [31:0] csr_mtvec;
    wire [31:0] csr_mepc;
    wire irq_pending;
    wire [31:0] irq_cause;
    wire take_interrupt_trap;
    wire mret_take = id_ex_valid && id_ex_mret && !pipeline_stall;

    pipeline_csr_unit u_csr (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr(if_id_csr_addr),
        .read_data(csr_read_data),
        .wb_valid(mem_wb_valid && !mem_wb_fault),
        .wb_csr_en(mem_wb_csr_en),
        .wb_csr_op(mem_wb_csr_op),
        .wb_csr_addr(mem_wb_csr_addr),
        .wb_csr_wdata(mem_wb_csr_wdata),
        .trap_take(take_interrupt_trap),
        .trap_pc(interrupt_resume_pc),
        .trap_cause(irq_cause),
        .mret_take(mret_take),
        .meip(meip),
        .mtip(mtip),
        .msip(msip),
        .mtvec_value(csr_mtvec),
        .mepc_value(csr_mepc),
        .irq_pending(irq_pending),
        .irq_cause(irq_cause)
    );

    wire [31:0] csr_ex_wdata = id_ex_csr_use_imm ? {27'b0, id_ex_rs1} : fwd_rs1;
    wire [31:0] ex_result = id_ex_csr_en ? id_ex_csr_rdata : alu_result;

    wire branch_taken = id_ex_valid && (
        (id_ex_branch_type == BR_BEQ  && (fwd_rs1 == fwd_rs2)) ||
        (id_ex_branch_type == BR_BNE  && (fwd_rs1 != fwd_rs2)) ||
        (id_ex_branch_type == BR_BLT  && ($signed(fwd_rs1) < $signed(fwd_rs2))) ||
        (id_ex_branch_type == BR_BGE  && ($signed(fwd_rs1) >= $signed(fwd_rs2))) ||
        (id_ex_branch_type == BR_BLTU && (fwd_rs1 < fwd_rs2)) ||
        (id_ex_branch_type == BR_BGEU && (fwd_rs1 >= fwd_rs2))
    );
    wire jump_taken = id_ex_valid && id_ex_jump;
    wire redirect_exec = branch_taken || jump_taken || mret_take;
    wire [31:0] branch_target = id_ex_pc + id_ex_imm;
    wire [31:0] jalr_target = (fwd_rs1 + id_ex_imm) & 32'hffff_fffe;
    wire [31:0] redirect_pc =
        mret_take ? csr_mepc :
        id_ex_jalr ? jalr_target :
                     branch_target;

    wire pipeline_empty = !if_id_valid && !id_ex_valid && !ex_mem_valid && !mem_wb_valid;
    wire enter_interrupt_drain = irq_pending && !interrupt_drain_active && !redirect_exec && !pipeline_stall;
    assign take_interrupt_trap = interrupt_drain_active && pipeline_empty && !pipeline_stall;
    wire perf_flush = (!pipeline_stall) && (redirect_exec || enter_interrupt_drain || take_interrupt_trap);

    assign imem_req = rst_n && !interrupt_drain_active;
    assign imem_addr = pc;

    cache #(
        .CACHE_LINES(DCACHE_LINES),
        .LINE_WORDS(DCACHE_LINE_WORDS)
    ) u_dcache (
        .clk(clk),
        .rst_n(rst_n),
        .req(core_dmem_req && core_dmem_cached),
        .addr(core_dmem_addr),
        .we(ex_mem_mem_write),
        .wdata(ex_mem_store_data),
        .width(ex_mem_mem_width),
        .ack(cache_ack),
        .rdata(cache_rdata),
        .fault(cache_fault),
        .mem_req(cache_dmem_req),
        .mem_we(cache_dmem_we),
        .mem_addr(cache_dmem_addr),
        .mem_wdata(cache_dmem_wdata),
        .mem_width(cache_dmem_width),
        .mem_ack(dmem_ack),
        .mem_rdata(dmem_rdata),
        .mem_fault(dmem_fault)
    );

    assign dmem_req = core_dmem_cached ? cache_dmem_req : core_dmem_req;
    assign dmem_addr = core_dmem_cached ? cache_dmem_addr : core_dmem_addr;
    assign dmem_we = core_dmem_cached ? cache_dmem_we : ex_mem_mem_write;
    assign dmem_wdata = core_dmem_cached ? cache_dmem_wdata : ex_mem_store_data;
    assign dmem_width = core_dmem_cached ? cache_dmem_width : ex_mem_mem_width;

    assign debug_pc = pc;

    pipeline_perf_counter u_perf (
        .clk(clk),
        .rst_n(rst_n),
        .stall(perf_stall),
        .flush(perf_flush),
        .instret(mem_wb_valid && !mem_wb_fault),
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
            if_id_instr <= 32'h0000_0013;

            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'b0;
            id_ex_pc4 <= 32'b0;
            id_ex_rs1_data <= 32'b0;
            id_ex_rs2_data <= 32'b0;
            id_ex_imm <= 32'b0;
            id_ex_csr_rdata <= 32'b0;
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
            id_ex_csr_en <= 1'b0;
            id_ex_csr_op <= 2'b00;
            id_ex_csr_use_imm <= 1'b0;
            id_ex_csr_addr <= 12'b0;
            id_ex_mret <= 1'b0;

            ex_mem_valid <= 1'b0;
            ex_mem_pc <= 32'b0;
            ex_mem_pc4 <= 32'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_imm <= 32'b0;
            ex_mem_csr_wdata <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_width <= 2'b00;
            ex_mem_wb_sel <= WB_ALU;
            ex_mem_fault <= 1'b0;
            ex_mem_csr_en <= 1'b0;
            ex_mem_csr_op <= 2'b00;
            ex_mem_csr_addr <= 12'b0;

            mem_wb_valid <= 1'b0;
            mem_wb_pc <= 32'b0;
            mem_wb_pc4 <= 32'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_imm <= 32'b0;
            mem_wb_csr_wdata <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_wb_sel <= WB_ALU;
            mem_wb_fault <= 1'b0;
            mem_wb_csr_en <= 1'b0;
            mem_wb_csr_op <= 2'b00;
            mem_wb_csr_addr <= 12'b0;

            interrupt_drain_active <= 1'b0;
            interrupt_resume_pc <= 32'b0;
            discard_imem_resp <= 1'b0;
        end else if (take_interrupt_trap) begin
            pc <= csr_mtvec;
            if_id_valid <= 1'b0;
            id_ex_valid <= 1'b0;
            ex_mem_valid <= 1'b0;
            mem_wb_valid <= 1'b0;
            interrupt_drain_active <= 1'b0;
            discard_imem_resp <= 1'b0;
        end else if (!pipeline_stall) begin
            interrupt_drain_active <= interrupt_drain_active || enter_interrupt_drain;
            if (enter_interrupt_drain) begin
                interrupt_resume_pc <= pc;
            end else if (interrupt_drain_active && redirect_exec) begin
                interrupt_resume_pc <= redirect_pc;
            end

            if (enter_interrupt_drain) begin
                pc <= pc;
                if_id_valid <= 1'b0;
                if (imem_wait) begin
                    discard_imem_resp <= 1'b1;
                end

                id_ex_valid <= if_id_valid;
                id_ex_pc <= if_id_pc;
                id_ex_pc4 <= if_id_pc4;
                id_ex_rs1_data <= rs1_data;
                id_ex_rs2_data <= rs2_data;
                id_ex_imm <= dec_imm;
                id_ex_csr_rdata <= csr_read_data;
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
                id_ex_csr_en <= dec_csr_en;
                id_ex_csr_op <= dec_csr_op;
                id_ex_csr_use_imm <= dec_csr_use_imm;
                id_ex_csr_addr <= if_id_csr_addr;
                id_ex_mret <= dec_mret;
            end else if (interrupt_drain_active) begin
                pc <= redirect_exec ? redirect_pc : pc;
                if_id_valid <= 1'b0;
                id_ex_valid <= 1'b0;
                if (redirect_exec && imem_wait) begin
                    discard_imem_resp <= 1'b1;
                end
            end else if (redirect_exec) begin
                pc <= redirect_pc;
                if_id_valid <= 1'b0;
                id_ex_valid <= 1'b0;
                if (imem_wait) begin
                    discard_imem_resp <= 1'b1;
                end
            end else begin
                // Consume the already-fetched IF/ID instruction every cycle the
                // back-end can run, even if the next instruction has not returned.
                id_ex_valid <= if_id_valid;
                id_ex_pc <= if_id_pc;
                id_ex_pc4 <= if_id_pc4;
                id_ex_rs1_data <= rs1_data;
                id_ex_rs2_data <= rs2_data;
                id_ex_imm <= dec_imm;
                id_ex_csr_rdata <= csr_read_data;
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
                id_ex_csr_en <= dec_csr_en;
                id_ex_csr_op <= dec_csr_op;
                id_ex_csr_use_imm <= dec_csr_use_imm;
                id_ex_csr_addr <= if_id_csr_addr;
                id_ex_mret <= dec_mret;

                if (imem_ack) begin
                    if (discard_imem_resp) begin
                        if_id_valid <= 1'b0;
                        discard_imem_resp <= 1'b0;
                    end else begin
                        pc <= pc + 32'd4;
                        if_id_valid <= 1'b1;
                        if_id_pc <= pc;
                        if_id_pc4 <= pc + 32'd4;
                        if_id_instr <= imem_data;
                    end
                end else begin
                    if_id_valid <= 1'b0;
                end
            end

            ex_mem_valid <= id_ex_valid;
            ex_mem_pc <= id_ex_pc;
            ex_mem_pc4 <= id_ex_pc4;
            ex_mem_alu_result <= ex_result;
            ex_mem_store_data <= fwd_rs2;
            ex_mem_imm <= id_ex_imm;
            ex_mem_csr_wdata <= csr_ex_wdata;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_width <= id_ex_mem_width;
            ex_mem_wb_sel <= id_ex_wb_sel;
            ex_mem_fault <= 1'b0;
            ex_mem_csr_en <= id_ex_csr_en;
            ex_mem_csr_op <= id_ex_csr_op;
            ex_mem_csr_addr <= id_ex_csr_addr;

            mem_wb_valid <= ex_mem_valid;
            mem_wb_pc <= ex_mem_pc;
            mem_wb_pc4 <= ex_mem_pc4;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= dmem_rsp_rdata;
            mem_wb_imm <= ex_mem_imm;
            mem_wb_csr_wdata <= ex_mem_csr_wdata;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_wb_sel <= ex_mem_wb_sel;
            mem_wb_fault <= ex_mem_fault || (mem_active && dmem_rsp_fault);
            mem_wb_csr_en <= ex_mem_csr_en;
            mem_wb_csr_op <= ex_mem_csr_op;
            mem_wb_csr_addr <= ex_mem_csr_addr;
        end else if (load_use_stall && !dmem_wait) begin
            id_ex_valid <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_csr_en <= 1'b0;
            id_ex_mret <= 1'b0;

            ex_mem_valid <= id_ex_valid;
            ex_mem_pc <= id_ex_pc;
            ex_mem_pc4 <= id_ex_pc4;
            ex_mem_alu_result <= ex_result;
            ex_mem_store_data <= fwd_rs2;
            ex_mem_imm <= id_ex_imm;
            ex_mem_csr_wdata <= csr_ex_wdata;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_width <= id_ex_mem_width;
            ex_mem_wb_sel <= id_ex_wb_sel;
            ex_mem_fault <= 1'b0;
            ex_mem_csr_en <= id_ex_csr_en;
            ex_mem_csr_op <= id_ex_csr_op;
            ex_mem_csr_addr <= id_ex_csr_addr;

            mem_wb_valid <= ex_mem_valid;
            mem_wb_pc <= ex_mem_pc;
            mem_wb_pc4 <= ex_mem_pc4;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= dmem_rsp_rdata;
            mem_wb_imm <= ex_mem_imm;
            mem_wb_csr_wdata <= ex_mem_csr_wdata;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_wb_sel <= ex_mem_wb_sel;
            mem_wb_fault <= ex_mem_fault || (mem_active && dmem_rsp_fault);
            mem_wb_csr_en <= ex_mem_csr_en;
            mem_wb_csr_op <= ex_mem_csr_op;
            mem_wb_csr_addr <= ex_mem_csr_addr;
        end
    end

endmodule
