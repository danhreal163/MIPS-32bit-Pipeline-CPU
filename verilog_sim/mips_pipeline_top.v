`timescale 1ns / 1ps
//==============================================================================
// Module: mips_pipeline_top.v
// Description: Top-Level 5-Stage Pipelined 32-bit MIPS Processor (IF, ID, EX, MEM, WB)
//              Integrates ALU, RegFile, Control_Unit, Pipeline Registers,
//              Hazard_Detection_Unit, Forwarding_Unit, Branch_Unit,
//              Instruction_Memory, and Data_Memory.
//==============================================================================

module mips_pipeline_top (
    input  wire        clk,
    input  wire        rst,
    // Debug / Observation Outputs
    output wire [31:0] pc_out,
    output wire [31:0] alu_result_mem_out,
    output wire [31:0] write_data_mem_out,
    output wire        mem_write_mem_out
);

    //==========================================================================
    // 1. IF Stage Signals & Logic
    //==========================================================================
    reg  [31:0] pc_reg;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4_if;
    wire [31:0] instr_if;

    // Stall & Flush control wires
    wire        stall_pc;
    wire        stall_if_id;
    wire        flush_if_id;
    wire        flush_id_ex;

    // Branch / Jump target wires from ID stage
    wire        pc_src_branch_id;
    wire        jump_id;
    wire [31:0] branch_target_id;
    wire [31:0] jump_target_id;

    assign pc_plus4_if = pc_reg + 32'd4;

    // Next-PC Multiplexer (Priority: Jump / Taken Branch in ID -> PC + 4)
    assign pc_next = jump_id          ? jump_target_id   :
                     pc_src_branch_id ? branch_target_id :
                                        pc_plus4_if;

    // Program Counter Register with synchronous reset and stall enable
    always @(posedge clk) begin
        if (rst) begin
            pc_reg <= 32'h0000_0000;
        end else if (!stall_pc) begin
            pc_reg <= pc_next;
        end
    end

    // Instruction Memory Instantiation
    Instruction_Memory u_imem (
        .addr  (pc_reg),
        .instr (instr_if)
    );

    //==========================================================================
    // 2. IF/ID Pipeline Register
    //==========================================================================
    wire [31:0] pc_plus4_id;
    wire [31:0] instr_id;

    IF_ID_Reg u_if_id (
        .clk          (clk),
        .rst          (rst),
        .stall        (stall_if_id),
        .flush        (flush_if_id),
        .pc_plus4_in  (pc_plus4_if),
        .instr_in     (instr_if),
        .pc_plus4_out (pc_plus4_id),
        .instr_out    (instr_id)
    );

    //==========================================================================
    // 3. ID Stage Signals & Logic
    //==========================================================================
    wire [5:0]  opcode_id   = instr_id[31:26];
    wire [4:0]  rs_id       = instr_id[25:21];
    wire [4:0]  rt_id       = instr_id[20:16];
    wire [4:0]  rd_id       = instr_id[15:11];
    wire [5:0]  funct_id    = instr_id[5:0];
    wire [15:0] imm_id      = instr_id[15:0];
    wire [25:0] jump_addr_id= instr_id[25:0];

    // Sign-Extension: 16-bit immediate -> 32-bit signed immediate
    wire [31:0] sign_imm_id = {{16{imm_id[15]}}, imm_id};

    // Control Unit Outputs
    wire        reg_write_id;
    wire        reg_dst_id;
    wire        alu_src_id;
    wire        branch_id;
    wire        mem_read_id;
    wire        mem_write_id;
    wire        mem_to_reg_id;
    wire [3:0]  alu_control_id;

    Control_Unit u_ctrl (
        .opcode      (opcode_id),
        .funct       (funct_id),
        .reg_write   (reg_write_id),
        .reg_dst     (reg_dst_id),
        .alu_src     (alu_src_id),
        .branch      (branch_id),
        .mem_read    (mem_read_id),
        .mem_write   (mem_write_id),
        .mem_to_reg  (mem_to_reg_id),
        .jump        (jump_id),
        .alu_control (alu_control_id)
    );

    // Register File Signals (connected to WB stage for writes)
    wire [31:0] rd1_raw_id;
    wire [31:0] rd2_raw_id;
    wire        reg_write_wb;
    wire [4:0]  write_reg_wb;
    wire [31:0] result_wb;

    // User's Verified RegFile Module Instantiation
    RegFile u_regfile (
        .clk (clk),
        .we3 (reg_write_wb),
        .a1  (rs_id),
        .a2  (rt_id),
        .a3  (write_reg_wb),
        .wd3 (result_wb),
        .rd1 (rd1_raw_id),
        .rd2 (rd2_raw_id)
    );

    // Explicit WB-to-ID Bypass (ensures correct operation even if RegFile
    // writes on posedge clk without internal write-through logic)
    wire [31:0] rd1_id = (reg_write_wb && (write_reg_wb != 5'b0) && (write_reg_wb == rs_id)) ? result_wb : rd1_raw_id;
    wire [31:0] rd2_id = (reg_write_wb && (write_reg_wb != 5'b0) && (write_reg_wb == rt_id)) ? result_wb : rd2_raw_id;

    // Early Branch Resolution Forwarding Muxes in ID (EX/MEM -> ID)
    wire        forward_a_id;
    wire        forward_b_id;
    wire [31:0] alu_result_mem;
    wire [31:0] branch_cmp_a = forward_a_id ? alu_result_mem : rd1_id;
    wire [31:0] branch_cmp_b = forward_b_id ? alu_result_mem : rd2_id;

    Branch_Unit u_branch (
        .pc_plus4_id   (pc_plus4_id),
        .sign_imm_id   (sign_imm_id),
        .jump_addr_id  (jump_addr_id),
        .cmp_a         (branch_cmp_a),
        .cmp_b         (branch_cmp_b),
        .branch_id     (branch_id),
        .jump_id       (jump_id),
        .stall_id      (stall_if_id),
        .pc_src_branch (pc_src_branch_id),
        .flush_if_id   (flush_if_id),
        .branch_target (branch_target_id),
        .jump_target   (jump_target_id)
    );

    //==========================================================================
    // 4. ID/EX Pipeline Register
    //==========================================================================
    wire        reg_write_ex;
    wire        mem_to_reg_ex;
    wire        mem_read_ex;
    wire        mem_write_ex;
    wire        reg_dst_ex;
    wire        alu_src_ex;
    wire [3:0]  alu_control_ex;
    wire [31:0] rd1_ex;
    wire [31:0] rd2_ex;
    wire [31:0] sign_imm_ex;
    wire [4:0]  rs_ex;
    wire [4:0]  rt_ex;
    wire [4:0]  rd_ex;

    ID_EX_Reg u_id_ex (
        .clk             (clk),
        .rst             (rst),
        .flush           (flush_id_ex),
        .reg_write_in    (reg_write_id),
        .mem_to_reg_in   (mem_to_reg_id),
        .mem_read_in     (mem_read_id),
        .mem_write_in    (mem_write_id),
        .reg_dst_in      (reg_dst_id),
        .alu_src_in      (alu_src_id),
        .alu_control_in  (alu_control_id),
        .rd1_in          (rd1_id),
        .rd2_in          (rd2_id),
        .sign_imm_in     (sign_imm_id),
        .rs_in           (rs_id),
        .rt_in           (rt_id),
        .rd_in           (rd_id),
        .reg_write_out   (reg_write_ex),
        .mem_to_reg_out  (mem_to_reg_ex),
        .mem_read_out    (mem_read_ex),
        .mem_write_out   (mem_write_ex),
        .reg_dst_out     (reg_dst_ex),
        .alu_src_out     (alu_src_ex),
        .alu_control_out (alu_control_ex),
        .rd1_out         (rd1_ex),
        .rd2_out         (rd2_ex),
        .sign_imm_out    (sign_imm_ex),
        .rs_out          (rs_ex),
        .rt_out          (rt_ex),
        .rd_out          (rd_ex)
    );

    //==========================================================================
    // 5. EX Stage Signals & Logic
    //==========================================================================
    wire [1:0]  forward_a_ex;
    wire [1:0]  forward_b_ex;
    wire [31:0] alu_src_a_ex;
    wire [31:0] alu_src_b_forwarded;
    wire [31:0] alu_src_b_ex;
    wire [31:0] alu_result_ex;
    wire        alu_zero_ex;
    wire [4:0]  write_reg_ex;

    // 3-to-1 Forwarding Multiplexer for ALU Input A
    assign alu_src_a_ex = (forward_a_ex == 2'b10) ? alu_result_mem :
                          (forward_a_ex == 2'b01) ? result_wb      :
                                                    rd1_ex;

    // 3-to-1 Forwarding Multiplexer for Register B (also used as sw write_data)
    assign alu_src_b_forwarded = (forward_b_ex == 2'b10) ? alu_result_mem :
                                 (forward_b_ex == 2'b01) ? result_wb      :
                                                           rd2_ex;

    // ALU Operand B Mux: select between forwarded rt register or sign-extended immediate
    assign alu_src_b_ex = alu_src_ex ? sign_imm_ex : alu_src_b_forwarded;

    // Destination Register Mux: rt (I-type lw) vs rd (R-type)
    assign write_reg_ex = reg_dst_ex ? rd_ex : rt_ex;

    // User's Verified ALU Module Instantiation
    ALU u_alu (
        .A           (alu_src_a_ex),
        .B           (alu_src_b_ex),
        .ALU_Control (alu_control_ex),
        .Result      (alu_result_ex),
        .Zero        (alu_zero_ex)
    );

    //==========================================================================
    // 6. EX/MEM Pipeline Register
    //==========================================================================
    wire        reg_write_mem;
    wire        mem_to_reg_mem;
    wire        mem_read_mem;
    wire        mem_write_mem;
    wire [31:0] write_data_mem;
    wire [4:0]  write_reg_mem;

    EX_MEM_Reg u_ex_mem (
        .clk            (clk),
        .rst            (rst),
        .reg_write_in   (reg_write_ex),
        .mem_to_reg_in  (mem_to_reg_ex),
        .mem_read_in    (mem_read_ex),
        .mem_write_in   (mem_write_ex),
        .alu_result_in  (alu_result_ex),
        .write_data_in  (alu_src_b_forwarded),
        .write_reg_in   (write_reg_ex),
        .reg_write_out  (reg_write_mem),
        .mem_to_reg_out (mem_to_reg_mem),
        .mem_read_out   (mem_read_mem),
        .mem_write_out  (mem_write_mem),
        .alu_result_out (alu_result_mem),
        .write_data_out (write_data_mem),
        .write_reg_out  (write_reg_mem)
    );

    //==========================================================================
    // 7. MEM Stage Signals & Logic
    //==========================================================================
    wire [31:0] read_data_mem;

    Data_Memory u_dmem (
        .clk        (clk),
        .rst        (rst),
        .mem_read   (mem_read_mem),
        .mem_write  (mem_write_mem),
        .addr       (alu_result_mem),
        .write_data (write_data_mem),
        .read_data  (read_data_mem)
    );

    //==========================================================================
    // 8. MEM/WB Pipeline Register
    //==========================================================================
    wire        mem_to_reg_wb;
    wire [31:0] read_data_wb;
    wire [31:0] alu_result_wb;

    MEM_WB_Reg u_mem_wb (
        .clk            (clk),
        .rst            (rst),
        .reg_write_in   (reg_write_mem),
        .mem_to_reg_in  (mem_to_reg_mem),
        .read_data_in   (read_data_mem),
        .alu_result_in  (alu_result_mem),
        .write_reg_in   (write_reg_mem),
        .reg_write_out  (reg_write_wb),
        .mem_to_reg_out (mem_to_reg_wb),
        .read_data_out  (read_data_wb),
        .alu_result_out (alu_result_wb),
        .write_reg_out  (write_reg_wb)
    );

    //==========================================================================
    // 9. WB Stage Logic
    //==========================================================================
    assign result_wb = mem_to_reg_wb ? read_data_wb : alu_result_wb;

    //==========================================================================
    // 10. Hazard Detection & Forwarding Units
    //==========================================================================
    Hazard_Detection_Unit u_hazard (
        .rs_id         (rs_id),
        .rt_id         (rt_id),
        .branch_id     (branch_id),
        .rt_ex         (rt_ex),
        .write_reg_ex  (write_reg_ex),
        .mem_read_ex   (mem_read_ex),
        .reg_write_ex  (reg_write_ex),
        .write_reg_mem (write_reg_mem),
        .mem_read_mem  (mem_read_mem),
        .stall_pc      (stall_pc),
        .stall_if_id   (stall_if_id),
        .flush_id_ex   (flush_id_ex)
    );

    Forwarding_Unit u_forwarding (
        .rs_id         (rs_id),
        .rt_id         (rt_id),
        .rs_ex         (rs_ex),
        .rt_ex         (rt_ex),
        .write_reg_mem (write_reg_mem),
        .reg_write_mem (reg_write_mem),
        .write_reg_wb  (write_reg_wb),
        .reg_write_wb  (reg_write_wb),
        .forward_a_ex  (forward_a_ex),
        .forward_b_ex  (forward_b_ex),
        .forward_a_id  (forward_a_id),
        .forward_b_id  (forward_b_id)
    );

    // Top-level observation outputs
    assign pc_out             = pc_reg;
    assign alu_result_mem_out = alu_result_mem;
    assign write_data_mem_out = write_data_mem;
    assign mem_write_mem_out  = mem_write_mem;

endmodule
