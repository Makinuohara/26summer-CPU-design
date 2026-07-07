module branch_unit (
    input wire [2:0] funct3,
    input wire [31:0] a,
    input wire [31:0] b,
    output reg take_branch
);
    always @(*) begin
        case (funct3)
            3'b000: take_branch = (a == b);
            3'b001: take_branch = (a != b);
            default: take_branch = 1'b0;
        endcase
    end
endmodule
