module instr_mem (
    input wire [31:0] addr,
    output reg [31:0] instr
);
    always @(*) begin
        case (addr[31:2])
            30'd0: instr = 32'h00500093; // addi x1, x0, 5
            30'd1: instr = 32'h00700113; // addi x2, x0, 7
            30'd2: instr = 32'h002081b3; // add  x3, x1, x2
            30'd3: instr = 32'h00302023; // sw   x3, 0(x0)
            30'd4: instr = 32'h00002203; // lw   x4, 0(x0)
            30'd5: instr = 32'h00418663; // beq  x3, x4, ok
            30'd6: instr = 32'h00000293; // addi x5, x0, 0
            30'd7: instr = 32'h0080006f; // jal  x0, end
            30'd8: instr = 32'h00100293; // ok: addi x5, x0, 1
            30'd9: instr = 32'h0000006f; // end: jal x0, end
            default: instr = 32'h0000006f;
        endcase
    end
endmodule
