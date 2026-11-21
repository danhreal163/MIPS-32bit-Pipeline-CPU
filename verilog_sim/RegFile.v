`timescale 1ns / 1ps
//==============================================================================
// Module: RegFile.v
// Description: 32x32-bit MIPS Register File matching the provided module header.
//              Register $0 is hardwired to 0. Includes internal write-through
//              forwarding for same-cycle WB/ID read-after-write.
//==============================================================================

module RegFile (
    input  wire        clk,
    input  wire        we3,
    input  wire [4:0]  a1,
    input  wire [4:0]  a2,
    input  wire [4:0]  a3,
    input  wire [31:0] wd3,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] rf [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            rf[i] = 32'b0;
        end
    end

    always @(posedge clk) begin
        if (we3 && (a3 != 5'b0)) begin
            rf[a3] <= wd3;
        end
    end

    assign rd1 = (a1 == 5'b0) ? 32'b0 :
                 ((we3 && (a1 == a3)) ? wd3 : rf[a1]);
    assign rd2 = (a2 == 5'b0) ? 32'b0 :
                 ((we3 && (a2 == a3)) ? wd3 : rf[a2]);
endmodule
