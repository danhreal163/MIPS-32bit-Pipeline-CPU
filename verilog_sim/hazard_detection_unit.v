`timescale 1ns / 1ps
//==============================================================================
// Module: hazard_detection_unit.v
// Description: Detects:
//              1) Classic Load-Use Data Hazards (lw in EX, dependent instr in ID)
//              2) ID-Stage Early Branch Hazards:
//                 - Producer instruction in EX writing to a register read by beq in ID
//                 - Load instruction (lw) in MEM writing to a register read by beq in ID
//              Stalls PC and IF/ID register, and flushes ID/EX to insert a bubble.
//==============================================================================

module Hazard_Detection_Unit (
    input  wire [4:0] rs_id,
    input  wire [4:0] rt_id,
    input  wire       branch_id,      // 1 if instruction in ID is beq
    input  wire [4:0] rt_ex,          // Destination register of lw in EX
    input  wire [4:0] write_reg_ex,   // Selected destination register (rt or rd) in EX
    input  wire       mem_read_ex,    // 1 if instruction in EX is lw
    input  wire       reg_write_ex,   // 1 if instruction in EX writes to RegFile
    input  wire [4:0] write_reg_mem,  // Destination register in MEM
    input  wire       mem_read_mem,   // 1 if instruction in MEM is lw
    output wire       stall_pc,       // Freeze PC
    output wire       stall_if_id,    // Freeze IF/ID pipeline register
    output wire       flush_id_ex     // Zero out ID/EX control signals (insert bubble)
);
    // 1. Standard Load-Use Hazard: lw in EX produces data needed by ID instruction
    wire load_use_hazard;
    assign load_use_hazard = mem_read_ex &&
                             ((rt_ex == rs_id) || (rt_ex == rt_id)) &&
                             (rt_ex != 5'b0);

    // 2. Early-Branch (ID-Stage) Data Hazard:
    //    (a) Any register-writing instruction in EX whose destination matches beq's rs/rt
    //    (b) A load instruction in MEM whose destination matches beq's rs/rt
    //        (ALU results in MEM are forwarded directly to ID without stalling)
    wire branch_ex_hazard;
    assign branch_ex_hazard = branch_id && reg_write_ex &&
                              (write_reg_ex != 5'b0) &&
                              ((write_reg_ex == rs_id) || (write_reg_ex == rt_id));

    wire branch_mem_load_hazard;
    assign branch_mem_load_hazard = branch_id && mem_read_mem &&
                                    (write_reg_mem != 5'b0) &&
                                    ((write_reg_mem == rs_id) || (write_reg_mem == rt_id));

    wire stall_condition;
    assign stall_condition = load_use_hazard || branch_ex_hazard || branch_mem_load_hazard;

    assign stall_pc    = stall_condition;
    assign stall_if_id = stall_condition;
    assign flush_id_ex = stall_condition;

endmodule
