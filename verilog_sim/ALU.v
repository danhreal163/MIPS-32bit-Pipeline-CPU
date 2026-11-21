`timescale 1ns / 1ps
//==============================================================================
// Module: ALU.v
// Description: 32-bit MIPS ALU matching the provided module header.
//              Replace with your own verified ALU.v if desired.
//==============================================================================

module ALU (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALU_Control,
    output reg  [31:0] Result,
    output wire        Zero
);
    always @(*) begin
        case (ALU_Control)
            4'b0000: Result = A & B;                         // AND
            4'b0001: Result = A | B;                         // OR
            4'b0010: Result = A + B;                         // ADD
            4'b0110: Result = A - B;                         // SUB
            4'b0111: Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0; // SLT
            default: Result = 32'd0;
        endcase
    end

    assign Zero = (Result == 32'd0);
endmodule
