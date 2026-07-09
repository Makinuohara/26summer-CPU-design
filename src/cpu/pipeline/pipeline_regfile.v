`timescale 1ns / 1ps

module pipeline_regfile (
    input wire clk,
    input wire rst_n,
    input wire reg_write,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    output wire [31:0] debug_x5
);
    reg [31:0] regs [0:31];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (reg_write && rd != 5'b0) begin
            regs[rd] <= write_data;
        end
    end

    assign read_data1 = (rs1 == 5'b0) ? 32'b0 :
                        ((reg_write && rd != 5'b0 && rd == rs1) ? write_data : regs[rs1]);
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 :
                        ((reg_write && rd != 5'b0 && rd == rs2) ? write_data : regs[rs2]);
    assign debug_x5 = regs[5];
endmodule
