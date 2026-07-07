module cpu_top (
    input wire clk,
    input wire rst,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_x5,
    output wire [31:0] debug_mem0
);
    wire [31:0] pc_current;
    wire [31:0] pc_plus4;
    wire [31:0] pc_branch;
    wire [31:0] pc_jump;
    wire [31:0] pc_next;
    wire [31:0] instr;
    wire [31:0] imm;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire [31:0] mem_read_data;
    wire [31:0] writeback_data;
    wire zero;
    wire take_branch;

    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire mem_to_reg;
    wire alu_src;
    wire branch;
    wire jump;
    wire [1:0] alu_op;
    wire [3:0] alu_ctrl;

    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    pc u_pc (
        .clk(clk),
        .rst(rst),
        .next_pc(pc_next),
        .pc(pc_current)
    );

    instr_mem u_instr_mem (
        .addr(pc_current),
        .instr(instr)
    );

    control_unit u_control_unit (
        .opcode(opcode),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_src(alu_src),
        .branch(branch),
        .jump(jump),
        .alu_op(alu_op)
    );

    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .reg_write(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(writeback_data),
        .read_data1(rs1_data),
        .read_data2(rs2_data),
        .debug_x5(debug_x5)
    );

    imm_gen u_imm_gen (
        .instr(instr),
        .imm(imm)
    );

    alu_control u_alu_control (
        .alu_op(alu_op),
        .funct3(funct3),
        .funct7(funct7),
        .alu_ctrl(alu_ctrl)
    );

    assign alu_b = alu_src ? imm : rs2_data;

    alu u_alu (
        .a(rs1_data),
        .b(alu_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero)
    );

    data_mem u_data_mem (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .addr(alu_result),
        .write_data(rs2_data),
        .read_data(mem_read_data),
        .debug_mem0(debug_mem0)
    );

    branch_unit u_branch_unit (
        .funct3(funct3),
        .a(rs1_data),
        .b(rs2_data),
        .take_branch(take_branch)
    );

    assign pc_plus4 = pc_current + 32'd4;
    assign pc_branch = pc_current + imm;
    assign pc_jump = pc_current + imm;
    assign pc_next = jump ? pc_jump : ((branch && take_branch) ? pc_branch : pc_plus4);
    assign writeback_data = jump ? pc_plus4 : (mem_to_reg ? mem_read_data : alu_result);
    assign debug_pc = pc_current;
endmodule
