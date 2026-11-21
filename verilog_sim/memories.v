`timescale 1ns / 1ps
//==============================================================================
// Module: memories.v
// Description: Word-aligned Instruction Memory (combinational read) and
//              Data Memory (synchronous write, combinational read).
//==============================================================================

module Instruction_Memory #(
    parameter MEM_DEPTH = 256
)(
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] rom [0:MEM_DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            rom[i] = 32'h0000_0000; // Default to NOP
        end
        // Optional: uncomment to load hex program from file
        // $readmemh("program.hex", rom);
    end

    // Word-aligned address indexing (addr[31:2])
    assign instr = rom[addr[9:2]];
endmodule

module Data_Memory #(
    parameter MEM_DEPTH = 256
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);
    reg [31:0] ram [0:MEM_DEPTH-1];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                ram[i] <= 32'h0000_0000;
            end
        end else if (mem_write) begin
            ram[addr[9:2]] <= write_data;
        end
    end

    assign read_data = mem_read ? ram[addr[9:2]] : 32'h0000_0000;
endmodule
