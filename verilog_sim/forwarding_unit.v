`timescale 1ns / 1ps
//==============================================================================
// Module: forwarding_unit.v
// Description: Resolves data hazards via forwarding:
//              1) EX-to-EX and MEM-to-EX forwarding to ALU inputs (forward_a_ex, forward_b_ex)
//              2) MEM-to-ID forwarding for early branch evaluation in ID stage
//                 (forward_a_id, forward_b_id)
//==============================================================================

module Forwarding_Unit (
    // ID-stage source registers (for early branch comparison in ID)
    input  wire [4:0] rs_id,
    input  wire [4:0] rt_id,
    // EX-stage source registers (for ALU execution in EX)
    input  wire [4:0] rs_ex,
    input  wire [4:0] rt_ex,
    // EX/MEM pipeline stage destination info
    input  wire [4:0] write_reg_mem,
    input  wire       reg_write_mem,
    // MEM/WB pipeline stage destination info
    input  wire [4:0] write_reg_wb,
    input  wire       reg_write_wb,

    // Forwarding mux selects for EX stage ALU operands:
    // 2'b00 = ID/EX register value
    // 2'b10 = Forward from EX/MEM (ALU result)
    // 2'b01 = Forward from MEM/WB (WB result)
    output reg  [1:0] forward_a_ex,
    output reg  [1:0] forward_b_ex,

    // Forwarding mux selects for ID stage Branch comparator:
    // 1'b0 = ID register value (with WB bypass)
    // 1'b1 = Forward from EX/MEM (ALU result)
    output wire       forward_a_id,
    output wire       forward_b_id
);

    //--------------------------------------------------------------------------
    // EX Stage Forwarding Logic (EX-to-EX has priority over MEM-to-EX)
    //--------------------------------------------------------------------------
    always @(*) begin
        // Operand A (rs_ex)
        if (reg_write_mem && (write_reg_mem != 5'b0) && (write_reg_mem == rs_ex)) begin
            forward_a_ex = 2'b10; // EX-to-EX hazard
        end else if (reg_write_wb && (write_reg_wb != 5'b0) && (write_reg_wb == rs_ex)) begin
            forward_a_ex = 2'b01; // MEM-to-EX hazard
        end else begin
            forward_a_ex = 2'b00; // No hazard
        end

        // Operand B (rt_ex)
        if (reg_write_mem && (write_reg_mem != 5'b0) && (write_reg_mem == rt_ex)) begin
            forward_b_ex = 2'b10; // EX-to-EX hazard
        end else if (reg_write_wb && (write_reg_wb != 5'b0) && (write_reg_wb == rt_ex)) begin
            forward_b_ex = 2'b01; // MEM-to-EX hazard
        end else begin
            forward_b_ex = 2'b00; // No hazard
        end
    end

    //--------------------------------------------------------------------------
    // ID Stage Forwarding Logic (EX/MEM ALU result -> ID Branch Comparator)
    //--------------------------------------------------------------------------
    assign forward_a_id = (reg_write_mem && (write_reg_mem != 5'b0) && (write_reg_mem == rs_id));
    assign forward_b_id = (reg_write_mem && (write_reg_mem != 5'b0) && (write_reg_mem == rt_id));

endmodule
