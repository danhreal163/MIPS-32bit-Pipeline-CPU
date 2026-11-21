`timescale 1ns / 1ps
//==============================================================================
// Module: pipeline_registers.v
// Description: 5-Stage MIPS Pipeline State Registers (IF/ID, ID/EX, EX/MEM, MEM/WB)
//              with synchronous active-high reset, stall (enable), and flush.
//==============================================================================

//------------------------------------------------------------------------------
// 1. IF/ID Pipeline Register
//------------------------------------------------------------------------------
module IF_ID_Reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,       // 1 = Hold current state (freeze IF/ID)
    input  wire        flush,       // 1 = Clear instruction to NOP (branch/jump taken)
    input  wire [31:0] pc_plus4_in,
    input  wire [31:0] instr_in,
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] instr_out
);
    always @(posedge clk) begin
        if (rst || (flush && !stall)) begin
            pc_plus4_out <= 32'b0;
            instr_out    <= 32'b0; // NOP (sll $0, $0, 0)
        end else if (!stall) begin
            pc_plus4_out <= pc_plus4_in;
            instr_out    <= instr_in;
        end
    end
endmodule

//------------------------------------------------------------------------------
// 2. ID/EX Pipeline Register
//------------------------------------------------------------------------------
module ID_EX_Reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,       // 1 = Insert NOP bubble into EX stage on stall
    // Control Signals (WB)
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    // Control Signals (MEM)
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    // Control Signals (EX)
    input  wire        reg_dst_in,
    input  wire        alu_src_in,
    input  wire [3:0]  alu_control_in,
    // Datapath Signals
    input  wire [31:0] rd1_in,
    input  wire [31:0] rd2_in,
    input  wire [31:0] sign_imm_in,
    input  wire [4:0]  rs_in,
    input  wire [4:0]  rt_in,
    input  wire [4:0]  rd_in,

    // Outputs to EX Stage
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         reg_dst_out,
    output reg         alu_src_out,
    output reg  [3:0]  alu_control_out,
    output reg  [31:0] rd1_out,
    output reg  [31:0] rd2_out,
    output reg  [31:0] sign_imm_out,
    output reg  [4:0]  rs_out,
    output reg  [4:0]  rt_out,
    output reg  [4:0]  rd_out
);
    always @(posedge clk) begin
        if (rst || flush) begin
            reg_write_out   <= 1'b0;
            mem_to_reg_out  <= 1'b0;
            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;
            reg_dst_out     <= 1'b0;
            alu_src_out     <= 1'b0;
            alu_control_out <= 4'b0000;
            rd1_out         <= 32'b0;
            rd2_out         <= 32'b0;
            sign_imm_out    <= 32'b0;
            rs_out          <= 5'b0;
            rt_out          <= 5'b0;
            rd_out          <= 5'b0;
        end else begin
            reg_write_out   <= reg_write_in;
            mem_to_reg_out  <= mem_to_reg_in;
            mem_read_out    <= mem_read_in;
            mem_write_out   <= mem_write_in;
            reg_dst_out     <= reg_dst_in;
            alu_src_out     <= alu_src_in;
            alu_control_out <= alu_control_in;
            rd1_out         <= rd1_in;
            rd2_out         <= rd2_in;
            sign_imm_out    <= sign_imm_in;
            rs_out          <= rs_in;
            rt_out          <= rt_in;
            rd_out          <= rd_in;
        end
    end
endmodule

//------------------------------------------------------------------------------
// 3. EX/MEM Pipeline Register
//------------------------------------------------------------------------------
module EX_MEM_Reg (
    input  wire        clk,
    input  wire        rst,
    // Control Signals (WB)
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    // Control Signals (MEM)
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    // Datapath Signals
    input  wire [31:0] alu_result_in,
    input  wire [31:0] write_data_in,
    input  wire [4:0]  write_reg_in,

    // Outputs to MEM Stage
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] write_data_out,
    output reg  [4:0]  write_reg_out
);
    always @(posedge clk) begin
        if (rst) begin
            reg_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            alu_result_out <= 32'b0;
            write_data_out <= 32'b0;
            write_reg_out  <= 5'b0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            alu_result_out <= alu_result_in;
            write_data_out <= write_data_in;
            write_reg_out  <= write_reg_in;
        end
    end
endmodule

//------------------------------------------------------------------------------
// 4. MEM/WB Pipeline Register
//------------------------------------------------------------------------------
module MEM_WB_Reg (
    input  wire        clk,
    input  wire        rst,
    // Control Signals (WB)
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    // Datapath Signals
    input  wire [31:0] read_data_in,
    input  wire [31:0] alu_result_in,
    input  wire [4:0]  write_reg_in,

    // Outputs to WB Stage
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg  [31:0] read_data_out,
    output reg  [31:0] alu_result_out,
    output reg  [4:0]  write_reg_out
);
    always @(posedge clk) begin
        if (rst) begin
            reg_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
            read_data_out  <= 32'b0;
            alu_result_out <= 32'b0;
            write_reg_out  <= 5'b0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            read_data_out  <= read_data_in;
            alu_result_out <= alu_result_in;
            write_reg_out  <= write_reg_in;
        end
    end
endmodule
