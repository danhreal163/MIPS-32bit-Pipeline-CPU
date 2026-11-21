`timescale 1ns / 1ps
//==============================================================================
// Module: control_unit.v
// Description: MIPS Control Unit consisting of Main_Decoder and ALU_Decoder.
//              Supports: R-type (add, sub, and, or, slt), lw, sw, beq, j.
//==============================================================================

module Main_Decoder (
    input  wire [5:0] opcode,
    output reg        reg_write,
    output reg        reg_dst,
    output reg        alu_src,
    output reg        branch,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        jump,
    output reg  [1:0] alu_op
);
    // MIPS Opcode Encodings
    localparam OP_RTYPE = 6'b000000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_BEQ   = 6'b000100;
    localparam OP_J     = 6'b000010;

    always @(*) begin
        // Default safe values (NOP)
        reg_write  = 1'b0;
        reg_dst    = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        jump       = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            OP_RTYPE: begin
                reg_write  = 1'b1;
                reg_dst    = 1'b1; // Write to rd (instr[15:11])
                alu_src    = 1'b0; // ALU operand B from register
                alu_op     = 2'b10; // Decode funct field
            end
            OP_LW: begin
                reg_write  = 1'b1;
                reg_dst    = 1'b0; // Write to rt (instr[20:16])
                alu_src    = 1'b1; // Sign-extended immediate offset
                mem_read   = 1'b1;
                mem_to_reg = 1'b1; // WB data from Data Memory
                alu_op     = 2'b00; // ALU performs ADD for address calculation
            end
            OP_SW: begin
                alu_src    = 1'b1; // Sign-extended immediate offset
                mem_write  = 1'b1;
                alu_op     = 2'b00; // ALU performs ADD for address calculation
            end
            OP_BEQ: begin
                branch     = 1'b1; // Resolved early in ID stage
                alu_op     = 2'b01; // SUB (if ALU is also used)
            end
            OP_J: begin
                jump       = 1'b1; // Resolved early in ID stage
            end
            default: begin
                // Remains all zeros (NOP)
            end
        endcase
    end
endmodule

module ALU_Decoder (
    input  wire [1:0] alu_op,
    input  wire [5:0] funct,
    output reg  [3:0] alu_control
);
    // Standard 4-bit MIPS ALU Control Encodings
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    // R-Type Funct Field Encodings
    localparam FUNCT_ADD = 6'b100000;
    localparam FUNCT_SUB = 6'b100010;
    localparam FUNCT_AND = 6'b100100;
    localparam FUNCT_OR  = 6'b100101;
    localparam FUNCT_SLT = 6'b101010;

    always @(*) begin
        case (alu_op)
            2'b00: alu_control = ALU_ADD; // lw / sw address addition
            2'b01: alu_control = ALU_SUB; // beq subtraction
            2'b10: begin                  // R-type instructions
                case (funct)
                    FUNCT_ADD: alu_control = ALU_ADD;
                    FUNCT_SUB: alu_control = ALU_SUB;
                    FUNCT_AND: alu_control = ALU_AND;
                    FUNCT_OR : alu_control = ALU_OR;
                    FUNCT_SLT: alu_control = ALU_SLT;
                    default  : alu_control = ALU_ADD;
                endcase
            end
            default: alu_control = ALU_ADD;
        endcase
    end
endmodule

module Control_Unit (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    output wire       reg_write,
    output wire       reg_dst,
    output wire       alu_src,
    output wire       branch,
    output wire       mem_read,
    output wire       mem_write,
    output wire       mem_to_reg,
    output wire       jump,
    output wire [3:0] alu_control
);
    wire [1:0] alu_op;

    Main_Decoder u_main_dec (
        .opcode     (opcode),
        .reg_write  (reg_write),
        .reg_dst    (reg_dst),
        .alu_src    (alu_src),
        .branch     (branch),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .mem_to_reg (mem_to_reg),
        .jump       (jump),
        .alu_op     (alu_op)
    );

    ALU_Decoder u_alu_dec (
        .alu_op      (alu_op),
        .funct       (funct),
        .alu_control (alu_control)
    );
endmodule
