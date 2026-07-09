`timescale 1ns / 1ps

module pipeline_perf_counter (
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire flush,
    input wire instret,
    output reg [31:0] cycle_count,
    output reg [31:0] instret_count,
    output reg [31:0] stall_count,
    output reg [31:0] flush_count
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 32'b0;
            instret_count <= 32'b0;
            stall_count <= 32'b0;
            flush_count <= 32'b0;
        end else begin
            cycle_count <= cycle_count + 32'd1;
            if (instret) begin
                instret_count <= instret_count + 32'd1;
            end
            if (stall) begin
                stall_count <= stall_count + 32'd1;
            end
            if (flush) begin
                flush_count <= flush_count + 32'd1;
            end
        end
    end
endmodule
