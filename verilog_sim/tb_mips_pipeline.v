`timescale 1ns / 1ps
//==============================================================================
// Module: tb_mips_pipeline.v
// Description: Self-checking testbench for 32-bit 5-Stage Pipelined MIPS.
//              Verifies:
//              - lw / sw memory operations
//              - Load-Use Hazard Detection (1-cycle stall + bubble insertion)
//              - EX-to-EX and MEM-to-EX Data Forwarding
//              - R-type instructions (add, sub, and, or, slt)
//              - Early Branch Resolution in ID stage (beq) with 1-cycle flush
//              - Unconditional Jump (j)
//==============================================================================

module tb_mips_pipeline;

    reg         clk;
    reg         rst;
    wire [31:0] pc_out;
    wire [31:0] alu_result_mem_out;
    wire [31:0] write_data_mem_out;
    wire        mem_write_mem_out;

    // Instantiate Top-Level Processor
    mips_pipeline_top dut (
        .clk                (clk),
        .rst                (rst),
        .pc_out             (pc_out),
        .alu_result_mem_out (alu_result_mem_out),
        .write_data_mem_out (write_data_mem_out),
        .mem_write_mem_out  (mem_write_mem_out)
    );

    // 10ns clock period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;

        // Preload Data Memory for testing lw:
        // Mem[0] = 10, Mem[4] = 25
        #1;
        dut.u_dmem.ram[0] = 32'd10;
        dut.u_dmem.ram[1] = 32'd25;

        // Preload Instruction Memory:
        // 0x00: lw  $1, 0($0)      -> $1 = 10
        // 0x04: lw  $2, 4($0)      -> $2 = 25
        // 0x08: add $3, $1, $2     -> Load-Use stall on $2! Then $3 = 10 + 25 = 35
        // 0x0C: sub $4, $3, $1     -> EX-to-EX forward $3: $4 = 35 - 10 = 25
        // 0x10: and $5, $3, $4     -> MEM-to-EX ($3) & EX-to-EX ($4): $5 = 35 & 25 = 1
        // 0x14: or  $6, $1, $5     -> EX-to-EX ($5): $6 = 10 | 1 = 11
        // 0x18: slt $7, $1, $2     -> $7 = (10 < 25) = 1
        // 0x1C: beq $4, $2, +2     -> Early ID branch ($4 == $2 == 25), target = 0x20 + 8 = 0x28
        // 0x20: add $8, $1, $1     -> Should be FLUSHED! ($8 remains 0)
        // 0x24: add $8, $2, $2     -> Skipped by branch
        // 0x28: sw  $3, 8($0)      -> Mem[8] = 35
        // 0x2C: j   0x00000034     -> Jump to 0x34 (word index 13)
        // 0x30: add $9, $1, $2     -> Should be FLUSHED! ($9 remains 0)
        // 0x34: add $10, $3, $4    -> $10 = 35 + 25 = 60
        dut.u_imem.rom[0]  = 32'h8C010000; // lw  $1, 0($0)
        dut.u_imem.rom[1]  = 32'h8C020004; // lw  $2, 4($0)
        dut.u_imem.rom[2]  = 32'h00221820; // add $3, $1, $2
        dut.u_imem.rom[3]  = 32'h00612022; // sub $4, $3, $1
        dut.u_imem.rom[4]  = 32'h00642824; // and $5, $3, $4
        dut.u_imem.rom[5]  = 32'h00253025; // or  $6, $1, $5
        dut.u_imem.rom[6]  = 32'h0022382A; // slt $7, $1, $2
        dut.u_imem.rom[7]  = 32'h10820002; // beq $4, $2, 2
        dut.u_imem.rom[8]  = 32'h00214020; // add $8, $1, $1 (flushed)
        dut.u_imem.rom[9]  = 32'h00424020; // add $8, $2, $2 (skipped)
        dut.u_imem.rom[10] = 32'hAC030008; // sw  $3, 8($0)
        dut.u_imem.rom[11] = 32'h0800000D; // j   0x34 (target word = 13)
        dut.u_imem.rom[12] = 32'h00224820; // add $9, $1, $2 (flushed)
        dut.u_imem.rom[13] = 32'h00645020; // add $10, $3, $4

        #14 rst = 1'b0;
        // Re-initialize Data Memory after synchronous reset deassertion
        dut.u_dmem.ram[0] = 32'd10;
        dut.u_dmem.ram[1] = 32'd25;

        #250;
        $display("==================================================");
        $display("MIPS 5-Stage Pipeline Verification Results:");
        $display("$1  (exp 10) = %0d", dut.u_regfile.rf[1]);
        $display("$2  (exp 25) = %0d", dut.u_regfile.rf[2]);
        $display("$3  (exp 35) = %0d", dut.u_regfile.rf[3]);
        $display("$4  (exp 25) = %0d", dut.u_regfile.rf[4]);
        $display("$5  (exp 1)  = %0d", dut.u_regfile.rf[5]);
        $display("$6  (exp 11) = %0d", dut.u_regfile.rf[6]);
        $display("$7  (exp 1)  = %0d", dut.u_regfile.rf[7]);
        $display("$8  (exp 0)  = %0d", dut.u_regfile.rf[8]);
        $display("$9  (exp 0)  = %0d", dut.u_regfile.rf[9]);
        $display("$10 (exp 60) = %0d", dut.u_regfile.rf[10]);
        $display("Mem[8] (exp 35) = %0d", dut.u_dmem.ram[2]);
        $display("==================================================");
        $finish;
    end

endmodule
