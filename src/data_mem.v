module data_mem #(
    parameter DEPTH = 256
) (
    input wire clk,
    input wire mem_read,
    input wire mem_write,
    input wire [31:0] addr,
    input wire [31:0] write_data,
    output wire [31:0] read_data,
    output wire [31:0] debug_mem0
);
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'b0;
        end
    end

    always @(posedge clk) begin
        if (mem_write) begin
            mem[addr[31:2]] <= write_data;
        end
    end

    assign read_data = mem_read ? mem[addr[31:2]] : 32'b0;
    assign debug_mem0 = mem[0];
endmodule
