# PS/2 Keyboard ISR: 7-segment display driver
#
# Behavior:
#   - Number keys 0-9: shift display left, new digit appears at rightmost
#   - Backspace (0x66): shift display right, leftmost becomes 0
#   - Enter (0x5A): clear all digits to 0
#
# Memory map:
#   DMEM 0x0000-0x001C: display buffer (8 words, one per digit, right-to-left)
#   DMEM 0x0100-0x011C: ISR register save area
#
# Scan codes (Nexys4 DDR PS/2 keyboard):
#   0:0x45  1:0x16  2:0x1E  3:0x26  4:0x25  5:0x2E  6:0x36  7:0x3D  8:0x3E  9:0x46
#   Enter:0x5A  Backspace:0x66

# ===== MAIN PROGRAM (starts at 0x00000000) =====

    # Clear display buffer in DMEM (8 words, offsets 0x00-0x1C)
    lui  x5, 0x0
    sw   x0, 0(x5)
    sw   x0, 4(x5)
    sw   x0, 8(x5)
    sw   x0, 12(x5)
    sw   x0, 16(x5)
    sw   x0, 20(x5)
    sw   x0, 24(x5)
    sw   x0, 28(x5)

    # Write zeros to all 8 SEG digit registers (SEG base: 0x80000010)
    lui  x5, 0x80000
    addi x5, x5, 0x10
    sw   x0, 4(x5)
    sw   x0, 8(x5)
    sw   x0, 12(x5)
    sw   x0, 16(x5)
    sw   x0, 20(x5)
    sw   x0, 24(x5)
    sw   x0, 28(x5)
    sw   x0, 32(x5)

    # Set mtvec = 0x100 (ISR entry point)
    lui  x5, 0x0
    addi x5, x5, 0x100
    csrrw x0, mtvec, x5

    # PLIC: Priority[2] = 1
    lui  x5, 0x81000
    addi x6, x0, 1
    sw   x6, 8(x5)

    # PLIC: Enable bit 2
    lui  x5, 0x81002
    addi x6, x0, 4
    sw   x6, 0(x5)

    # PLIC: Threshold = 0
    lui  x5, 0x81200
    sw   x0, 0(x5)

    # Enable MEIE in mie
    lui  x5, 0x1
    addi x5, x5, 0x800
    csrrs x0, mie, x5

    # Enable MIE in mstatus (global interrupt enable)
    addi x5, x0, 8
    csrrs x0, mstatus, x5

    # Enable PS/2 controller (enable=1, irq_en=1)
    lui  x5, 0x80000
    lui  x6, 0x0
    addi x6, x6, 0x101
    sw   x6, 0(x5)

    # Turn on LED0 as heartbeat (running indicator)
    addi x6, x0, 1
    sw   x6, 12(x5)

    # Main loop: wait for interrupts
    addi x0, x0, 0
    jal  x0, -4

# ===== ISR at 0x100 =====
.org 0x100

    # Save registers to DMEM scratch area (0x100-0x11C)
    lui  x5, 0x0
    addi x5, x5, 0x100
    sw   x6, 0(x5)
    sw   x7, 4(x5)
    sw   x10, 8(x5)
    sw   x11, 12(x5)
    sw   x12, 16(x5)
    sw   x13, 20(x5)
    sw   x14, 24(x5)
    sw   x15, 28(x5)

    # Read claim ID from PLIC (0x81200004)
    lui  x5, 0x81200
    lw   x10, 4(x5)

    # If claim == 0, spurious interrupt; skip to finish
    beq  x10, x0, isr_finish

    # Read PS/2 scan code (PS2_RDATA at 0x80000004)
    lui  x5, 0x80000
    lw   x11, 4(x5)
    andi x11, x11, 0xFF

    # Check Enter (0x5A)
    addi x6, x0, 0x5A
    beq  x11, x6, isr_enter

    # Check Backspace (0x66)
    addi x6, x0, 0x66
    beq  x11, x6, isr_backspace

    # Lookup digit from scan code → x12
    jal  x1, lookup_digit
    # If x12 < 0, not a digit; skip
    blt  x12, x0, isr_finish

    # Shift left: buf[6]→buf[7], buf[5]→buf[6], ..., buf[0]→buf[1], digit→buf[0]
    lui  x5, 0x0
    lw   x6, 24(x5)
    sw   x6, 28(x5)
    lw   x6, 20(x5)
    sw   x6, 24(x5)
    lw   x6, 16(x5)
    sw   x6, 20(x5)
    lw   x6, 12(x5)
    sw   x6, 16(x5)
    lw   x6, 8(x5)
    sw   x6, 12(x5)
    lw   x6, 4(x5)
    sw   x6, 8(x5)
    lw   x6, 0(x5)
    sw   x6, 4(x5)
    sw   x12, 0(x5)
    jal  x0, isr_write_seg

isr_backspace:
    # Shift right: buf[1]→buf[0], ..., buf[7]→buf[6], 0→buf[7]
    lui  x5, 0x0
    lw   x6, 4(x5)
    sw   x6, 0(x5)
    lw   x6, 8(x5)
    sw   x6, 4(x5)
    lw   x6, 12(x5)
    sw   x6, 8(x5)
    lw   x6, 16(x5)
    sw   x6, 12(x5)
    lw   x6, 20(x5)
    sw   x6, 16(x5)
    lw   x6, 24(x5)
    sw   x6, 20(x5)
    lw   x6, 28(x5)
    sw   x6, 24(x5)
    sw   x0, 28(x5)
    jal  x0, isr_write_seg

isr_enter:
    # Clear all: buf[0..7] = 0
    lui  x5, 0x0
    sw   x0, 0(x5)
    sw   x0, 4(x5)
    sw   x0, 8(x5)
    sw   x0, 12(x5)
    sw   x0, 16(x5)
    sw   x0, 20(x5)
    sw   x0, 24(x5)
    sw   x0, 28(x5)
    jal  x0, isr_write_seg

isr_write_seg:
    # Write all 8 digits from DMEM buf[0..7] to SEG digit registers
    # SEG base: 0x80000010, DIGIT0 at +4, DIGIT1 at +8, ..., DIGIT7 at +32
    lui  x5, 0x80000
    addi x5, x5, 0x10
    lui  x13, 0x0
    lw   x6, 0(x13)
    sw   x6, 4(x5)
    lw   x6, 4(x13)
    sw   x6, 8(x5)
    lw   x6, 8(x13)
    sw   x6, 12(x5)
    lw   x6, 12(x13)
    sw   x6, 16(x5)
    lw   x6, 16(x13)
    sw   x6, 20(x5)
    lw   x6, 20(x13)
    sw   x6, 24(x5)
    lw   x6, 24(x13)
    sw   x6, 28(x5)
    lw   x6, 28(x13)
    sw   x6, 32(x5)

isr_finish:
    # Complete interrupt: write claim ID back (0x81200004)
    lui  x5, 0x81200
    sw   x10, 4(x5)

    # Restore registers
    lui  x5, 0x0
    addi x5, x5, 0x100
    lw   x6, 0(x5)
    lw   x7, 4(x5)
    lw   x10, 8(x5)
    lw   x11, 12(x5)
    lw   x12, 16(x5)
    lw   x13, 20(x5)
    lw   x14, 24(x5)
    lw   x15, 28(x5)

    mret


# ===== Lookup digit from PS/2 scan code =====
# Input:  x11 = scan code
# Output: x12 = digit (0-9) or -1
# Clobbers: x6
lookup_digit:
    addi x6, x0, 0x45
    bne  x11, x6, ld_1
    addi x12, x0, 0
    jalr x0, x1, 0
ld_1:
    addi x6, x0, 0x16
    bne  x11, x6, ld_2
    addi x12, x0, 1
    jalr x0, x1, 0
ld_2:
    addi x6, x0, 0x1E
    bne  x11, x6, ld_3
    addi x12, x0, 2
    jalr x0, x1, 0
ld_3:
    addi x6, x0, 0x26
    bne  x11, x6, ld_4
    addi x12, x0, 3
    jalr x0, x1, 0
ld_4:
    addi x6, x0, 0x25
    bne  x11, x6, ld_5
    addi x12, x0, 4
    jalr x0, x1, 0
ld_5:
    addi x6, x0, 0x2E
    bne  x11, x6, ld_6
    addi x12, x0, 5
    jalr x0, x1, 0
ld_6:
    addi x6, x0, 0x36
    bne  x11, x6, ld_7
    addi x12, x0, 6
    jalr x0, x1, 0
ld_7:
    addi x6, x0, 0x3D
    bne  x11, x6, ld_8
    addi x12, x0, 7
    jalr x0, x1, 0
ld_8:
    addi x6, x0, 0x3E
    bne  x11, x6, ld_9
    addi x12, x0, 8
    jalr x0, x1, 0
ld_9:
    addi x6, x0, 0x46
    bne  x11, x6, ld_fail
    addi x12, x0, 9
    jalr x0, x1, 0
ld_fail:
    addi x12, x0, -1
    jalr x0, x1, 0
