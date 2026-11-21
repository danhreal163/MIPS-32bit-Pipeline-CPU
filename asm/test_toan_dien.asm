# =========================================================================
# KICH BAN KIEM THU TOAN DIEN 100% (GOLDEN BENCHMARK - 27 LENH)
# CPU MIPS 32-bit 5-Stage Pipeline (15/15 Instructions + Full Hazards)
# Cau hinh MARS neu dich lai: Settings -> Memory Configuration -> Compact, Text at Address 0
# =========================================================================

.text
main:
    # --- NHOM 1: EX/MEM Forwarding (10) & Double Data Hazard ---
    addi $1, $0, 5        # [0x00] $1 = 5
    addi $1, $1, 7        # [0x04] Forward EX/MEM ($1=5) -> $1 = 12
    addi $1, $1, 3        # [0x08] Double Data Hazard (uu tien EX/MEM=12 hon MEM/WB=5) -> $1 = 15

    # --- NHOM 2: SignExtend am, slt co dau, sll/srl/ori, Logic & Bao ve cung $0 ---
    addi $2, $0, -4       # [0x0C] SignExtend so am -> $2 = -4 (0xFFFFFFFC)
    slt  $3, $2, $1       # [0x10] Forward kep (EX/MEM $2=-4, MEM/WB $1=15): -4 < 15 -> $3 = 1
    sll  $4, $3, 4        # [0x14] Forward EX/MEM ($3=1): 1 << 4 -> $4 = 16
    ori  $4, $4, 5        # [0x18] Forward EX/MEM ($4=16), ZeroExtend: 16 | 5 -> $4 = 21
    srl  $4, $4, 1        # [0x1C] Forward EX/MEM ($4=21): 21 >> 1 -> $4 = 10
    sub  $5, $1, $4       # [0x20] Forward EX/MEM ($4=10): 15 - 10 -> $5 = 5
    and  $6, $1, $4       # [0x24] Forward MEM/WB ($4=10): 15 & 10 -> $6 = 10
    or   $0, $1, $4       # [0x28] Thu ghi de 15 vao $0 -> $0 van phai bang 0!
    nor  $2, $0, $0       # [0x2C] Test chan Forward $0 (WriteRegM!=0): ~(0 | 0) -> $2 = -1 (0xFFFFFFFF)
    add  $5, $5, $2       # [0x30] Forward EX/MEM ($2=-1): 5 + (-1) -> $5 = 4

    # --- NHOM 3: DMEM (sw -> lw) & Load-Use Data Hazard (lwstall 1 chu ky) ---
    sw   $1, 8($0)        # [0x34] Ghi $1 = 15 vao DMEM[8] (Word 2)
    lw   $6, 8($0)        # [0x38] Doc DMEM[8] = 15 vao $6
    add  $7, $6, $5       # [0x3C] Load-Use Hazard! Stall 1 chu ky + Forward MEM/WB -> $7 = 15 + 4 = 19

    # --- NHOM 4: ALU-to-Branch Stall (1 chu ky) + ForwardAD + beq (Not-Taken & Taken) ---
    beq  $7, $5, trap1    # [0x40] Stall 1 chu ky doi add $7, ForwardAD=1: 19 == 4 (Sai -> Khong nhay)
    beq  $6, $1, br1_ok   # [0x44] 15 == 15 (Dung -> Nhay qua trap1, FlushD = 1!)
trap1:
    addi $7, $0, 99       # [0x48] LENH BAY #1 (Bi Flush va bo qua -> $7 khong bi thanh 99)

    # --- NHOM 5: Load-to-Branch Stall (2 chu ky lien tiep) + bne (Not-Taken & Taken) ---
br1_ok:
    lw   $3, 8($0)        # [0x4C] Doc DMEM[8] = 15 vao $3
    bne  $3, $1, trap2    # [0x50] Stall 2 chu ky lien tiep doi lw $3! 15 != 15 (Sai -> Khong nhay)
    bne  $3, $5, br2_ok   # [0x54] 15 != 4 (Dung -> Nhay qua trap2, FlushD = 1!)
trap2:
    addi $3, $0, 88       # [0x58] LENH BAY #2 (Bi Flush va bo qua -> $3 khong bi thanh 88)

    # --- NHOM 6: Unconditional Jump (j) & Vong lap dung an toan (halt) ---
br2_ok:
    j    finish           # [0x5C] Nhay khong dieu kien toi finish (0x64), FlushD = 1!
trap3:
    addi $5, $0, 77       # [0x60] LENH BAY #3 (Bi j Flush va bo qua -> $5 khong bi thanh 77)
finish:
    addi $2, $7, 1        # [0x64] Chot ket qua cuoi cung: $2 = 19 + 1 = 20 (0x14)
halt:
    j    halt             # [0x68] Giu CPU dung yen an toan tai 0x68, khong bi chay lap lai tu dau!
