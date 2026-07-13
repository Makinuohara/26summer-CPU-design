# Codex project guide

## Project overview

- This repository implements a five-stage RV32I SoC for the Nexys 4 DDR in Verilog.
- The active design is under `src/cpu/pipeline/`, `src/io/`, `src/memory/`, `src/soc.v`, and `src/fpga_top.v`.
- Testbenches and program images live in `sim/`; Vivado and file-list scripts live in `scripts/`.
- Treat `ABI.md` as the programming-model reference and the documents under `docs/设计方案/` as design context. When documentation disagrees with RTL, verify the RTL and update the documentation together if the task includes that scope.

## Working conventions

- Run commands from the repository root because file lists, Tcl scripts, and `$readmemh` paths are relative to it.
- Keep the design compatible with Verilog-2001 and Vivado 2018.3 unless a file already requires a newer language mode. Testbenches may be compiled with `iverilog -g2012`.
- Preserve module interfaces unless the requested change explicitly requires an interface update. If an interface changes, update every instantiation, relevant file list, testbench, and design document in the same change.
- Use nonblocking assignments in clocked sequential logic and blocking assignments in combinational logic. Keep reset polarity and synchronous/asynchronous reset behavior consistent with the surrounding module.
- Make width and signedness explicit for arithmetic, shifts, comparisons, address decoding, and CSR/MMIO constants. Avoid implicit nets.
- Add or extend a focused self-checking testbench for behavioral RTL changes. Tests must finish with a clear `PASS`/`FAIL` result and a bounded timeout.
- When adding or renaming RTL/testbench files, update every affected `scripts/filelist*.f` and Vivado Tcl source list.
- If ISA, CSR, memory-map, or MMIO behavior changes, update `ABI.md` and the relevant file under `docs/设计方案/`.
- Do not rewrite unrelated files or normalize line endings across the repository. The working tree may contain in-progress user changes.

## Verification

Prefer the narrowest relevant test first. Write temporary simulator outputs under `/tmp` so generated files do not pollute the repository.

Common Icarus Verilog regressions:

```bash
iverilog -g2012 -s tb_pipeline_cpu_irq -o /tmp/tb_pipeline_cpu_irq.vvp -c scripts/filelist_pipeline_irq.f && vvp /tmp/tb_pipeline_cpu_irq.vvp
iverilog -g2012 -s tb_interrupt_controller -o /tmp/tb_interrupt_controller.vvp src/io/interrupt_controller.v sim/tb_interrupt_controller.v && vvp /tmp/tb_interrupt_controller.vvp
```

The memory, I/O, and SoC integration testbenches currently instantiate an older `dmem_bus_decoder` interface. Treat failures mentioning removed `dmem_we`, `dmem_wdata`, or `dmem_width` ports as testbench/file-list drift; reconcile the testbench with the current RTL before using those suites as regression evidence.

Assemble a program with:

```bash
python3 scripts/asembler.py sim/<program>.asm /tmp/<program>.hex
```

For changes affecting synthesis, constraints, clocking, the FPGA top level, or memory initialization, also run the appropriate Vivado 2018.3 batch flow when available:

```bash
vivado -mode batch -source scripts/vivado_build_nexys4ddr.tcl
```

Report explicitly when Vivado or board programming was not run. Never claim board-level verification from simulation alone.

## Generated and sensitive areas

- Do not manually edit or commit generated content in `.Xil/`, `build/`, `vivado_*/`, `xsim.dir/`, `*.vvp`, `*.wdb`, or Vivado log/journal files.
- Do not program the FPGA unless the user explicitly asks; programming changes external hardware state.
- Do not change pin constraints casually. Any edit under `constraints/` must be checked against the Nexys 4 DDR board mapping and the selected top-level ports.
- Do not replace checked-in `.hex`/`.mem` images unless the task changes their source program or explicitly requests regeneration; record the source `.asm` and assembler command used.
