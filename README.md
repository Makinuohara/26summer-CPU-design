# 基于nexys4 ddr 的RISC-V 32I SoC

采用哈佛结构，内含五级流水线 RV32I CPU，PLIC 中断控制器，集成 PS/2 键盘、滑动开关、7 段数码管，LED灯等外设。

## 快速开始（汇编 → 下载 → 运行）

当前演示程序：PS/2 键盘输入数字 → 数码管滑动显示。

### 0. 编写汇编源码

 例：sim/ps2_keyboard_isr.asm

编程模型详见 [`ABI.md`](ABI.md)。

### 1. 汇编为16进制

```powershell
python scripts\assembler.py sim\ps2_keyboard_isr.asm sim\ps2_keyboard_isr.hex
```

### 2. 生成 bitstream（vivado路径需要根据实际情况修改）

```powershell
& 'D:\vivado18\installed\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_build_nexys4ddr.tcl
```

产物：`build/bitstreams/fpga_top.bit`

### 3. 烧录到板子

```powershell
& 'D:\vivado18\installed\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\program_fpga_top.tcl
```

## 上板操作

- 插上 PS/2 键盘，LED0 亮起代表 CPU 就绪
- **数字键 0-9**：从右侧滑入（如依次按 1,2,3 → `00000123`）
- **退格键**：右移一位，左侧补 0
- **回车键**：清空全部数字

## 仿真（Vivado xsim）

```powershell
& 'D:\vivado18\installed\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\sim_isr_test.tcl
```

## SoC系统架构

```
fpga_top（Nexys 4 DDR 顶层）
  └── soc
        ├── pipeline_cpu_top          — 5 级流水线 RV32I CPU
        │     ├── pipeline_control_unit  — RV32I + CSR 译码
        │     ├── pipeline_csr_unit      — mstatus / mie / mtvec / mepc / mcause
        │     ├── pipeline_forwarding_unit — 数据前递
        │     ├── pipeline_hazard_unit   — 取数冒险检测
        │     └── pipeline_alu / imm_gen / regfile
        ├── imem                     — 指令 ROM（$readmemh 加载 hex）
        ├── dmem + cache             — 数据存储器（直写）
        ├── dmem_bus_decoder         — MMIO 地址译码
        ├── io_ps2 / io_switches / io_leds / io_seg7 / io_buttons
        └── interrupt_controller     — PLIC（16 源、优先级、claim/complete）
```

## 工程目录

```text
src/cpu/pipeline/   9 个流水线模块
src/io/             7 个外设模块 + 总线解码器 + 中断控制器
src/memory/         imem / dmem / cache + 共享后端 memory_internal.vh
src/soc.v           SoC 顶层集成
src/fpga_top.v      FPGA 板级顶层
constraints/        Nexys 4 DDR 引脚约束
scripts/            汇编器、综合、烧录脚本
sim/                汇编源码 / testbench / hex 文件
docs/               设计方案文档
```

## 开发参考

- [`ABI.md`](ABI.md) — 完整 ISA、CSR、内存映射、IO 寄存器、PLIC 编程手册
- [`AGENTS.md`](AGENTS.md) — 本仓库的 AI agent 开发指令
- [`docs/调试日志.md`](docs/调试日志.md) — 板卡连接调试记录
