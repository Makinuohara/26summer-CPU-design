# AGENTS.md — 26summer-CPU-design

RISC-V RV32I pipeline CPU on Nexys4 DDR (xc7a100tcsg324-1). Tooling: Icarus Verilog (sim) + Vivado 2018.3 (synthesis).

## Key commands

### Run any pipeline simulation (Icarus)
```powershell
# Full SoC integration smoke test (pipeline CPU + all IO + memory + cache):
& 'D:\iverilog\bin\iverilog.exe' -g2012 -s tb_pipeline_soc_integration -o sim\soc_smoke.vvp -c scripts\filelist_pipeline_soc_integration.f
& 'D:\iverilog\bin\vvp.exe' sim\soc_smoke.vvp

# Other targets: substitute TOP_MODULE and filelist:
#   tb_pipeline_cpu_irq       → scripts\filelist_pipeline.f
#   tb_pipeline_io_integration → scripts\filelist_pipeline_io_integration.f
#   tb_pipeline_memory_integration → scripts\filelist_pipeline_memory_integration.f
#   tb_cpu_top                → scripts\filelist.f (Layer 1 single-cycle)
```

### Build FPGA bitstream (Vivado)
```powershell
# Full SoC bitstream (uses constraints/nexys4ddr_minimal.xdc, src list from scripts/filelist_fpga_top.f):
& 'D:\vivado18\installed\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_build_nexys4ddr.tcl
# Output: build/bitstreams/fpga_top.bit

# Pipeline CPU smoke (minimal) FPGA test:
& 'D:\vivado18\installed\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_build_pipeline_cpu_smoke.tcl

# LED chaser (JTAG chain verification):
& 'D:\vivado18\installed\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_build_led_chaser.tcl
```

## Architecture

### Module hierarchy (top-down)
```
fpga_top (parameter CLK_DIV_BITS=18)
  └── soc
        ├── clk_div              → divides 100 MHz → ~381 Hz cpu_clk
        ├── pipeline_cpu_top     → 5-stage IF/ID/EX/MEM/WB pipeline, full RV32I
        ├── imem (via memory_internal.vh)  → instruction ROM, init from hex file
        ├── dmem → cache (direct-mapped, write-through)
        ├── dmem_bus_decoder     → routes MMIO
        ├── io_ps2, io_switches, io_leds, io_seg7, io_buttons
        └── interrupt_controller → PLIC-like (16 sources, priority + claim/complete)
```

### Source layout
```
src/
  cpu/pipeline/   — 9 pipeline stage modules
  io/             — 6 peripheral modules + dmem_bus_decoder + interrupt_controller
  memory/         — imem, dmem, cache, memory_internal.vh (shared backend)
  fpga_top.v      — board top-level
  soc.v           — SoC integration
  fpga_demo_imem.v — standalone demo ROM (not in main SOC chain)
```

### Memory map (ABI.md has full details)
```
0x00000000 — IMEM (16 KB)
0x08000000 — DMEM + cache (16 KB physical)
0x80000000 — PS/2 CTRL/RDATA
0x80000008 — Switches
0x8000000C — LEDs
0x80000010 — 7-seg base (DIGIT0..7 at +0x04..+0x20)
0x80000030 — Buttons
0x81000000 — PLIC (PRIORITY, ENABLE, THRESHOLD, CLAIM)
```

### CPU features & quirks
- 5-stage pipeline with forwarding (EX/MEM and MEM/WB → EX) and load-use stall
- Full RV32I + Machine-mode CSRs (mstatus, mie, mtvec, mepc, mcause, mip)
- Interrupt: MEI only (via PLIC source 2 = PS/2); mtip/msip hardwired 0
- Interrupt drain-before-take: pipeline drains then jumps to mtvec
- `clk_div` uses CLK_DIV_BITS=18 → CPU runs at ~381 Hz (100 MHz / 2^18)
- PS/2: hardware consumes F0/E0 prefix bytes; software sees final byte only
- Buttons: hardwired to 0 in fpga_top (not physically connected)
- Data memory: write-through cache, write-no-allocate
- DMEM uses word addresses only (lw/sw), no LB/SB support
- Hex file format: `@ADDR` (byte addr) followed by 32-bit hex words per line

## Writing assembly for this CPU

- Use `scripts/assembler.py` to assemble: `python scripts/assembler.py input.asm output.hex`
- ADDI sign-extends the 12-bit immediate — to load a positive value with bit 11 set, use `lui` followed by `addi` (e.g., load 0x800: `lui x5, 0; addi x5, x5, 0x800` would NOT work due to sign extension; use `lui x5, 0x1; addi x5, x5, 0x800` to get 0x1800 instead)
- ISR MUST manually save/restore all used registers to DMEM (no hardware stacking)
- MRET encoding: `0x30200073`
- CSR addresses: mstatus=0x300, mie=0x304, mtvec=0x305, mepc=0x341, mcause=0x342

## PS/2 keyboard scan codes (relevant subset)
```
0:0x45  1:0x16  2:0x1E  3:0x26  4:0x25  5:0x2E  6:0x36  7:0x3D  8:0x3E  9:0x46
Enter:0x5A  Backspace:0x66
```

## Build system notes

- Filelists in `scripts/*.f` are consumed by both Icarus Verilog (`-c`) and Vivado (TCL reads them)
- `filelist_pipeline_soc_integration.f` is the most complete filelist for simulation
- `filelist_fpga_top.f` is the full FPGA synthesis filelist
- Hex init is via Verilog `$readmemh` through the `IMEM_INIT_FILE` parameter on `soc` (defaults changed via `soc.v` parameter)
- Vivado project directories (`vivado_*/`) are gitignored and regenerated each build
- The `constraints/nexys4ddr_minimal.xdc` file is the one used by SoC bitstream builds

## Key references

- `ABI.md` — full ISA, CSR, memory map, I/O register, PLIC programming manual
- `README.md` — project overview and three-layer design goals
- `docs/调试日志.md` — board connection debug log
- `references/assignment/` — course materials and board manuals
