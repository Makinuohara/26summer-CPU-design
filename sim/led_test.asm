    # Minimal test: just light all LEDs and loop
    lui  x5, 0x80000
    addi x6, x0, 0xFF
    sw   x6, 12(x5)
    jal  x0, -4
