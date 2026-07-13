# IPC Benchmark for 5-stage pipeline RV32I
#
# 4 micro-benchmarks, results displayed via switch-triggered ISR.
# SW[1:0] selects test, SW edge triggers PLIC source 10 → ISR updates display.
#
# DMEM:
#   0x200+0..0x1C: test results (cycle_diff, instret_diff) × 4
#   0x220+0..0x0C: precomputed IPC*100 × 4
#   0x240+0..0x1C: ISR register save area
#
# mtvec = 0x200

    # === Init ===
    lui  x8, 0x0
    addi x8, x8, 0x200       # DMEM results base
    lui  x9, 0x80000          # IO base
    sw   x0, 12(x9)           # LED = 0

    # === Run all 4 tests ===
    addi x5, x0, 1
    slli x5, x5, 8
    sw   x5, 12(x9)
    jal  x1, do_test

    addi x5, x0, 2
    slli x5, x5, 8
    sw   x5, 12(x9)
    jal  x1, do_test

    addi x5, x0, 3
    slli x5, x5, 8
    sw   x5, 12(x9)
    jal  x1, do_test

    addi x5, x0, 4
    slli x5, x5, 8
    sw   x5, 12(x9)
    jal  x1, do_test

    # === Precompute IPC*100 for all 4 tests ===
    # Results go to DMEM[0x220 + idx*4]
    addi x5, x0, 0
ipc_pre:
    slli x6, x5, 3
    add  x6, x8, x6
    lw   x7, 0(x6)           # cycle_diff
    lw   x10, 4(x6)          # instret_diff

    addi x11, x0, 100
    add  x12, x0, x0
ipc_mul:
    add  x12, x12, x10
    addi x11, x11, -1
    bne  x11, x0, ipc_mul

    add  x13, x0, x0
    beq  x7, x0, ipc_store
ipc_div:
    blt  x12, x7, ipc_store
    sub  x12, x12, x7
    addi x13, x13, 1
    jal  x0, ipc_div
ipc_store:
    slli x6, x5, 2
    addi x6, x6, 0x20
    add  x6, x8, x6
    sw   x13, 0(x6)

    addi x5, x5, 1
    addi x11, x0, 4
    bne  x5, x11, ipc_pre

    # === Setup switch interrupt ===
    # mtvec = 0x200
    lui  x5, 0x0
    addi x5, x5, 0x200
    csrrw x0, mtvec, x5

    # PLIC: PRIORITY[10] = 1
    lui  x5, 0x81000
    addi x6, x0, 1
    sw   x6, 0x28(x5)        # offset 10*4=40=0x28

    # PLIC: ENABLE bit 10
    lui  x5, 0x81002
    addi x6, x0, 0x400       # bit 10 = 1024
    sw   x6, 0(x5)

    # PLIC: THRESHOLD = 0
    lui  x5, 0x81200
    sw   x0, 0(x5)

    # Enable MEIE, then MIE
    lui  x5, 0x1
    addi x5, x5, 0x800
    csrrs x0, mie, x5
    addi x5, x0, 8
    csrrs x0, mstatus, x5

    # Spin — all display updates via ISR
    addi x0, x0, 0
    jal  x0, -4


# ===== ISR at 0x200 =====
.org 0x200
isr_entry:
    # Save registers to DMEM[0x240..0x25C]
    lui  x5, 0x0
    addi x5, x5, 0x240
    sw   x6, 0(x5)
    sw   x7, 4(x5)
    sw   x10, 8(x5)
    sw   x11, 12(x5)
    sw   x12, 16(x5)
    sw   x13, 20(x5)
    sw   x14, 24(x5)
    sw   x15, 28(x5)

    # Read CLAIM
    lui  x5, 0x81200
    lw   x10, 4(x5)
    beq  x10, x0, isr_done

    # Read SW[1:0] to select test
    lui  x5, 0x80000
    lw   x11, 8(x5)
    andi x11, x11, 0x3

    # LED: test_num << 8 | ipc
    addi x12, x11, 1
    slli x12, x12, 8

    # Load IPC from DMEM[0x220 + idx*4]
    slli x6, x11, 2
    addi x6, x6, 0x20
    lui  x7, 0x0
    addi x7, x7, 0x200
    add  x6, x7, x6
    lw   x13, 0(x6)
    or   x12, x12, x13
    sw   x12, 12(x5)

    # Load instret from DMEM[0x200 + idx*8 + 4]
    slli x6, x11, 3
    add  x6, x7, x6
    lw   x14, 4(x6)

    # SEG: instret hex low 4 digits
    lui  x5, 0x80000
    addi x5, x5, 0x10
    andi x15, x14, 0xF
    sw   x15, 4(x5)
    srli x14, x14, 4
    andi x15, x14, 0xF
    sw   x15, 8(x5)
    srli x14, x14, 4
    andi x15, x14, 0xF
    sw   x15, 12(x5)
    srli x14, x14, 4
    andi x15, x14, 0xF
    sw   x15, 16(x5)

    # Complete
    lui  x5, 0x81200
    sw   x10, 4(x5)

isr_done:
    # Restore
    lui  x5, 0x0
    addi x5, x5, 0x240
    lw   x6, 0(x5)
    lw   x7, 4(x5)
    lw   x10, 8(x5)
    lw   x11, 12(x5)
    lw   x12, 16(x5)
    lw   x13, 20(x5)
    lw   x14, 24(x5)
    lw   x15, 28(x5)
    mret


# ===== Test harness (unchanged) =====
do_test:
    lw   x6, 0x38(x9)
    lw   x7, 0x3C(x9)

    lw   x10, 12(x9)
    srli x10, x10, 8

    addi x5, x0, 1
    beq  x10, x5, run_alu
    addi x5, x0, 2
    beq  x10, x5, run_ld
    addi x5, x0, 3
    beq  x10, x5, run_br
    addi x5, x0, 4
    beq  x10, x5, run_mix
    jalr x0, x1, 0

run_alu:
    addi x5, x0, 32
alu_lp:
    addi x11, x11, 1
    addi x12, x12, 2
    andi x13, x13, 0xF
    ori  x14, x14, 1
    xori x15, x15, 1
    slli x16, x16, 1
    srli x17, x17, 1
    add  x11, x11, x12
    addi x5, x5, -1
    bne  x5, x0, alu_lp
    jal  x0, test_done

run_ld:
    addi x5, x0, 32
ld_lp:
    lw   x10, 0x20(x8)
    addi x10, x10, 1
    sw   x10, 0x20(x8)
    addi x5, x5, -1
    bne  x5, x0, ld_lp
    jal  x0, test_done

run_br:
    addi x5, x0, 32
br_lp:
    addi x5, x5, -1
    bne  x5, x0, br_lp
    jal  x0, test_done

run_mix:
    addi x5, x0, 32
mix_lp:
    lw   x10, 0x20(x8)
    addi x10, x10, 1
    addi x11, x11, 2
    sw   x10, 0x20(x8)
    addi x5, x5, -1
    bne  x5, x0, mix_lp

test_done:
    lw   x10, 0x38(x9)
    lw   x11, 0x3C(x9)
    sub  x12, x10, x6
    sub  x13, x11, x7
    sw   x12, 0(x8)
    sw   x13, 4(x8)
    addi x8, x8, 8
    jalr x0, x1, 0
