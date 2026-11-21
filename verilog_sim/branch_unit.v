`timescale 1ns / 1ps
//==============================================================================
// Module: branch_unit.v
// Description: Early Branch & Jump Resolution Unit in the ID Stage.
//              Computes branch target address, jump target address, equality
//              comparison, next PC selection, and IF/ID flush signal.
//==============================================================================

module Branch_Unit (
    input  wire [31:0] pc_plus4_id,
    input  wire [31:0] sign_imm_id,
    input  wire [25:0] jump_addr_id,   // Instr_ID[25:0]
    input  wire [31:0] cmp_a,          // Forwarded rs value in ID
    input  wire [31:0] cmp_b,          // Forwarded rt value in ID
    input  wire        branch_id,      // Control: beq in ID
    input  wire        jump_id,        // Control: j in ID
    input  wire        stall_id,       // Prevent false branch flush while ID is stalled
    output wire        pc_src_branch,  // 1 if beq is taken
    output wire        flush_if_id,    // Flush IF/ID on taken branch or jump (1-cycle penalty)
    output wire [31:0] branch_target,
    output wire [31:0] jump_target
);
    wire equal_id;
    assign equal_id      = (cmp_a == cmp_b);
    assign pc_src_branch = branch_id && equal_id;

    // Branch target = PC + 4 + (SignImm << 2)
    assign branch_target = pc_plus4_id + {sign_imm_id[29:0], 2'b00};

    // Jump target = { (PC + 4)[31:28], Instr[25:0], 2'b00 }
    assign jump_target   = {pc_plus4_id[31:28], jump_addr_id, 2'b00};

    // Flush the instruction currently being fetched in IF when branch/jump resolves taken
    assign flush_if_id   = (pc_src_branch || jump_id) && !stall_id;

endmodule
