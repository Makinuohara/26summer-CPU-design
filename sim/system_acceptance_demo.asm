# Complete RV32I SoC acceptance demo
#
# SW[15:12] selects a page; SW[11:0] is page input.
#   0 self-test, 1 MMIO mirror, 2 ALU, 3 DMEM/cache,
#   4 Fibonacci, 5 pipeline benchmark, 6 interrupt dashboard,
#   7 PS/2 dashboard.
#
# DMEM layout:
#   0x000..0x00c cache test line, 0x100 conflict line
#   0x200 switch snapshot, 0x204 switch IRQ count
#   0x208 last claim ID, 0x20c PS/2 scan code, 0x210 PS/2 IRQ count
#   0x380 benchmark marker, 0x400.. ISR save area

    # Clear software-visible state.
    lui  x5, 0
    sw   x0, 0x204(x5)
    sw   x0, 0x208(x5)
    sw   x0, 0x20c(x5)
    sw   x0, 0x210(x5)
    sw   x0, 0x380(x5)

    # Capture the initial switch value before enabling its interrupt.
    lui  x6, 0x80000
    lw   x7, 8(x6)
    sw   x7, 0x200(x5)

    # mtvec = 0x800.
    lui  x7, 0x1
    addi x7, x7, 0x800
    csrrw x0, mtvec, x7

    # PLIC priority: source 2 (PS/2) = 2, source 10 (switches) = 1.
    lui  x6, 0x81000
    addi x7, x0, 2
    sw   x7, 8(x6)
    addi x7, x0, 1
    sw   x7, 40(x6)

    # Enable sources 2 and 10, threshold = 0.
    lui  x6, 0x81002
    addi x7, x0, 0x404
    sw   x7, 0(x6)
    lui  x6, 0x81200
    sw   x0, 0(x6)

    # Enable the PS/2 receiver and CPU machine external interrupts.
    lui  x6, 0x80000
    addi x7, x0, 0x101
    sw   x7, 0(x6)
    lui  x7, 0x1
    addi x7, x7, 0x800
    csrrs x0, mie, x7
    addi x7, x0, 8
    csrrs x0, mstatus, x7

main_loop:
    lui  x5, 0
    lw   x6, 0x200(x5)
    srli x7, x6, 12
    andi x7, x7, 0xf
    beq  x7, x0, page_self_test
    addi x8, x0, 1
    beq  x7, x8, page_mmio
    addi x8, x0, 2
    beq  x7, x8, page_alu
    addi x8, x0, 3
    beq  x7, x8, page_memory
    addi x8, x0, 4
    beq  x7, x8, page_fibonacci
    addi x8, x0, 5
    beq  x7, x8, page_benchmark
    addi x8, x0, 6
    beq  x7, x8, page_interrupts
    jal  x0, page_ps2

page_self_test:
    # ALU and forwarding checks.
    addi x10, x0, 5
    addi x11, x0, 7
    add  x12, x10, x11
    addi x13, x0, 12
    bne  x12, x13, self_test_fail
    sub  x12, x12, x10
    bne  x12, x11, self_test_fail
    xor  x12, x10, x11
    addi x13, x0, 2
    bne  x12, x13, self_test_fail
    slli x12, x10, 3
    addi x13, x0, 40
    bne  x12, x13, self_test_fail

    # Branch and DMEM/cache read-after-write checks.
    addi x12, x0, 0x55
    sw   x12, 0(x5)
    lw   x13, 0(x5)
    bne  x12, x13, self_test_fail
    addi x12, x0, -1
    blt  x12, x0, self_test_pass
    jal  x0, self_test_fail

self_test_pass:
    lui  x10, 0x600dc
    addi x10, x10, 0x0de
    lui  x11, 0x10
    addi x11, x11, -1
    jal  x1, write_outputs
    jal  x0, main_loop

self_test_fail:
    lui  x10, 0xdeadc
    addi x10, x10, 0x0de
    addi x11, x0, 0
    jal  x1, write_outputs
    jal  x0, main_loop

page_mmio:
    # Display 1000xxxx and mirror all switches to LEDs.
    lui  x10, 0x10000
    or   x10, x10, x6
    add  x11, x6, x0
    jal  x1, write_outputs
    jal  x0, main_loop

page_alu:
    # y = (((x + 3) XOR 0x5a) << 1) & 0xff.
    andi x12, x6, 0xff
    addi x13, x12, 3
    xori x13, x13, 0x5a
    slli x13, x13, 1
    andi x13, x13, 0xff
    lui  x10, 0x20000
    slli x14, x12, 8
    or   x10, x10, x14
    or   x10, x10, x13
    add  x11, x13, x0
    jal  x1, write_outputs
    jal  x0, main_loop

page_memory:
    # Fill one cache line with p..p+3 and verify its checksum.
    andi x12, x6, 0xff
    sw   x12, 0(x5)
    addi x13, x12, 1
    sw   x13, 4(x5)
    addi x13, x12, 2
    sw   x13, 8(x5)
    addi x13, x12, 3
    sw   x13, 12(x5)
    lw   x14, 0(x5)
    lw   x15, 4(x5)
    add  x14, x14, x15
    lw   x15, 8(x5)
    add  x14, x14, x15
    lw   x15, 12(x5)
    add  x14, x14, x15

    # Address 0x100 has the same direct-mapped cache index as address 0.
    addi x16, x0, 0x100
    sw   x14, 0(x16)
    lw   x15, 0(x16)
    bne  x14, x15, memory_fail
    lw   x15, 0(x5)
    bne  x12, x15, memory_fail
    lui  x10, 0x30000
    andi x14, x14, 0xfff
    or   x10, x10, x14
    lui  x11, 0x10
    addi x11, x11, -1
    jal  x1, write_outputs
    jal  x0, main_loop

memory_fail:
    lui  x10, 0x3bad0
    addi x11, x0, 0
    jal  x1, write_outputs
    jal  x0, main_loop

page_fibonacci:
    andi x12, x6, 0xf
    addi x13, x0, 0
    addi x14, x0, 1
    addi x15, x0, 0
fib_loop:
    beq  x15, x12, fib_done
    add  x16, x13, x14
    add  x13, x14, x0
    add  x14, x16, x0
    addi x15, x15, 1
    jal  x0, fib_loop
fib_done:
    lui  x10, 0x40000
    slli x16, x12, 16
    or   x10, x10, x16
    or   x10, x10, x13
    add  x11, x13, x0
    jal  x1, write_outputs
    jal  x0, main_loop

page_benchmark:
    # Marker writes delimit workloads for the acceptance testbench.
    addi x20, x0, 0x380
    addi x21, x0, 0x51
    sw   x21, 0(x20)
    addi x12, x0, 0
    addi x13, x0, 16
bench_alu:
    addi x12, x12, 3
    xori x14, x12, 0x55
    add  x15, x14, x12
    addi x13, x13, -1
    bne  x13, x0, bench_alu

    addi x21, x0, 0x52
    sw   x21, 0(x20)
    sw   x12, 0(x5)
    addi x13, x0, 16
bench_load_use:
    lw   x14, 0(x5)
    addi x14, x14, 1
    sw   x14, 0(x5)
    addi x13, x13, -1
    bne  x13, x0, bench_load_use

    addi x21, x0, 0x53
    sw   x21, 0(x20)
    addi x13, x0, 16
bench_branch:
    addi x12, x12, 1
    addi x13, x13, -1
    bne  x13, x0, bench_branch

    addi x21, x0, 0x54
    sw   x21, 0(x20)
    addi x16, x0, 0x100
    addi x13, x0, 8
bench_conflict:
    lw   x14, 0(x5)
    lw   x15, 0(x16)
    add  x12, x12, x14
    add  x12, x12, x15
    addi x13, x13, -1
    bne  x13, x0, bench_conflict

    addi x21, x0, 0x55
    sw   x21, 0(x20)
    lui  x10, 0x50000
    andi x12, x12, 0xfff
    or   x10, x10, x12
    addi x11, x0, 0x1f
    jal  x1, write_outputs
    jal  x0, main_loop

page_interrupts:
    lw   x12, 0x204(x5)
    lw   x13, 0x208(x5)
    lui  x10, 0x60000
    slli x13, x13, 16
    or   x10, x10, x13
    andi x12, x12, 0xffff
    or   x10, x10, x12
    ori  x11, x12, 1
    jal  x1, write_outputs
    jal  x0, main_loop

page_ps2:
    lw   x12, 0x20c(x5)
    lw   x13, 0x210(x5)
    lui  x10, 0x70000
    slli x13, x13, 16
    or   x10, x10, x13
    andi x12, x12, 0xff
    or   x10, x10, x12
    add  x11, x12, x0
    jal  x1, write_outputs
    jal  x0, main_loop

# Input x10: eight displayed hex digits; x11: LED value.
# Clobbers x20 and x21.
write_outputs:
    lui  x20, 0x80000
    sw   x11, 12(x20)
    addi x20, x20, 0x10
    add  x21, x10, x0
    andi x11, x21, 0xf
    sw   x11, 4(x20)
    srli x21, x21, 4
    andi x11, x21, 0xf
    sw   x11, 8(x20)
    srli x21, x21, 4
    andi x11, x21, 0xf
    sw   x11, 12(x20)
    srli x21, x21, 4
    andi x11, x21, 0xf
    sw   x11, 16(x20)
    srli x21, x21, 4
    andi x11, x21, 0xf
    sw   x11, 20(x20)
    srli x21, x21, 4
    andi x11, x21, 0xf
    sw   x11, 24(x20)
    srli x21, x21, 4
    andi x11, x21, 0xf
    sw   x11, 28(x20)
    srli x21, x21, 4
    andi x11, x21, 0xf
    sw   x11, 32(x20)
    jalr x0, x1, 0

# Machine external interrupt handler.
.org 0x800
isr_entry:
    addi x5, x0, 0x400
    sw   x1, 0(x5)
    sw   x6, 4(x5)
    sw   x7, 8(x5)
    sw   x8, 12(x5)
    sw   x9, 16(x5)
    sw   x10, 20(x5)
    sw   x11, 24(x5)
    sw   x12, 28(x5)
    sw   x13, 32(x5)
    sw   x14, 36(x5)
    sw   x15, 40(x5)
    sw   x16, 44(x5)
    sw   x17, 48(x5)
    sw   x18, 52(x5)
    sw   x19, 56(x5)
    sw   x20, 60(x5)
    sw   x21, 64(x5)

    lui  x6, 0x81200
    lw   x10, 4(x6)
    lui  x7, 0
    sw   x10, 0x208(x7)
    beq  x10, x0, isr_restore
    addi x11, x0, 10
    beq  x10, x11, isr_switch
    addi x11, x0, 2
    beq  x10, x11, isr_ps2
    jal  x0, isr_complete

isr_switch:
    lui  x11, 0x80000
    lw   x12, 8(x11)
    sw   x12, 0x200(x7)
    lw   x13, 0x204(x7)
    addi x13, x13, 1
    sw   x13, 0x204(x7)
    jal  x0, isr_complete

isr_ps2:
    lui  x11, 0x80000
    lw   x12, 4(x11)
    andi x12, x12, 0xff
    sw   x12, 0x20c(x7)
    lw   x13, 0x210(x7)
    addi x13, x13, 1
    sw   x13, 0x210(x7)

isr_complete:
    lui  x6, 0x81200
    sw   x10, 4(x6)

isr_restore:
    addi x5, x0, 0x400
    lw   x1, 0(x5)
    lw   x6, 4(x5)
    lw   x7, 8(x5)
    lw   x8, 12(x5)
    lw   x9, 16(x5)
    lw   x10, 20(x5)
    lw   x11, 24(x5)
    lw   x12, 28(x5)
    lw   x13, 32(x5)
    lw   x14, 36(x5)
    lw   x15, 40(x5)
    lw   x16, 44(x5)
    lw   x17, 48(x5)
    lw   x18, 52(x5)
    lw   x19, 56(x5)
    lw   x20, 60(x5)
    lw   x21, 64(x5)
    mret
