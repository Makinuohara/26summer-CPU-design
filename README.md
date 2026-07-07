# RV32I CPU 三级层次设计

本仓库用于项目式课程阶段二的 CPU 设计任务。当前已经完成第一层基础层次：一个可仿真、可综合、可在 Nexys 4 DDR 上观察结果的单周期 RV32I 子集 CPU。

## 目录结构

```text
src/                    第一层 CPU RTL 源码
sim/                    Icarus Verilog 仿真 testbench 与程序备份
constraints/            Nexys 4 DDR 引脚约束
scripts/                仿真、综合、下载辅助脚本
docs/                   ISA 与数据通路设计说明
examples/led_chaser/    独立流水灯例程，用于验证板卡/JTAG 下载链路
build/bitstreams/       当前保留的 bitstream 快照
references/assignment/  课程资料、板卡手册、任务图片等原始参考文件
```

Vivado 生成目录 `vivado_nexys4ddr/`、`vivado_led_chaser/` 和日志文件都是可再生成产物，不作为核心工程文件保留。

## 三个层次

### 第一层：基础 CPU

目标是完成最小但闭环的 CPU：参照 RISC-V RV32I 子集设计指令集、数据通路与控制器，用 Verilog 实现并通过仿真和 Nexys 4 DDR 综合实现验证。

当前完成情况：

```text
算术：add, sub, addi
逻辑：and, or, xor, andi, ori, xori
访存：lw, sw
跳转/分支：beq, bne, jal
```

目前内置测试程序已经覆盖 `addi -> add -> sw -> lw -> beq -> addi` 这条主链路，能够证明算术、访存、分支跳转可以闭环运行。逻辑类指令已经在控制器和 ALU 中实现，后续可以补充专门的 `and/or/xor` 测试程序作为更直观的展示。

### 第二层：扩展 CPU

在基础 CPU 上扩展更多指令和外设观察方式，例如：

```text
更多 RV32I 指令：sll, srl, sra, slti, lui, auipc, jalr 等
更完整的分支：blt, bge, bltu, bgeu
更清晰的调试输出：寄存器选择、内存地址选择、UART 输出
```

这一层重点是让 CPU 更接近完整 RV32I，并让测试程序覆盖更多指令组合。

### 第三层：提高 CPU

进一步提高结构复杂度和可展示性，例如：

```text
多周期 CPU：把取指、译码、执行、访存、写回拆成多个状态
流水线 CPU：典型 IF/ID/EX/MEM/WB 五级流水
冒险处理：数据前递、暂停、分支冲刷
外设系统：按键、LED、数码管、UART 或简单总线
```

这里要注意：多周期 CPU 和流水线 CPU 不是一回事。多周期是“一条指令分多个时钟状态完成”；流水线是“多条指令在不同阶段并行推进”。

## 第一层实现思路

第一层采用单周期结构，每个时钟周期完成一条指令。整体数据通路如下：

```text
PC
  -> instr_mem 取指
  -> control_unit / imm_gen / regfile 译码和读寄存器
  -> alu_control / alu / branch_unit 执行与分支判断
  -> data_mem 访存
  -> regfile 写回
  -> PC 更新为 PC+4、分支目标或 jal 目标
```

核心模块对应关系：

```text
src/pc.v             PC 寄存器
src/instr_mem.v      指令 ROM，内置第一层测试程序
src/control_unit.v   主控制器，根据 opcode 产生控制信号
src/imm_gen.v        立即数生成器
src/regfile.v        32 个通用寄存器，x0 恒为 0
src/alu_control.v    根据 ALUOp/funct3/funct7 选择 ALU 操作
src/alu.v            算术逻辑运算单元
src/branch_unit.v    beq/bne 分支判断
src/data_mem.v       数据存储器，支持 lw/sw
src/cpu_top.v        CPU 数据通路顶层
src/fpga_top.v       Nexys 4 DDR 上板顶层，连接开关、LED、数码管
src/clk_div.v        上板观察用慢时钟分频
src/seg7_hex.v       七段数码管十六进制显示
```

## 第一层测试程序

`src/instr_mem.v` 内置的测试程序逻辑是：

```asm
addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2      # x3 = 12
sw   x3, 0(x0)       # mem[0] = 12
lw   x4, 0(x0)       # x4 = mem[0]
beq  x3, x4, ok      # 读回正确则跳转
addi x5, x0, 0       # 失败标志
jal  x0, end
ok:
addi x5, x0, 1       # 成功标志
end:
jal  x0, end
```

验收结果：

```text
x5 = 1
data_mem[0] = 0x0000000c
```

这说明 CPU 已经完成了：

```text
addi/add：产生 5 + 7 = 12
sw/lw：把 12 写入内存再读回
beq/jal：根据比较结果跳到成功路径，并停在 end 循环
```

## 仿真验证

本机工具路径：

```text
Icarus Verilog: D:\iverilog\bin
Vivado:         D:\Vivado\Vivado\2018.3\bin
```

运行：

```powershell
cd D:\26summer-CPU-design
& 'D:\iverilog\bin\iverilog.exe' -g2012 -s tb_cpu_top -o sim\cpu_smoke.vvp -c scripts\filelist.f
& 'D:\iverilog\bin\vvp.exe' sim\cpu_smoke.vvp
```

期望输出：

```text
PASS: single-cycle RV32I subset smoke test passed
```

## Vivado 综合与生成 bitstream

生成第一层 CPU bitstream：

```powershell
cd D:\26summer-CPU-design
& 'D:\Vivado\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_build_nexys4ddr.tcl
```

生成结果会复制到：

```text
build/bitstreams/fpga_top.bit
```

也可以先生成流水灯 bitstream 验证板卡下载链路：

```powershell
& 'D:\Vivado\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts\vivado_build_led_chaser.tcl
```

生成结果：

```text
build/bitstreams/led_chaser_top.bit
```

## Nexys 4 DDR 上板观察

下载 `build/bitstreams/fpga_top.bit` 后，使用 `SW[1:0]` 选择 LED/数码管显示内容：

```text
00：PC 低 16 位
01：x5 低 16 位，预期为 0001
10：data_mem[0] 低 16 位，预期为 000c
11：固定调试常量
```

如果 `SW=01` 显示 `1`，说明测试程序进入成功路径；如果 `SW=10` 显示 `0x000c`，说明访存结果正确。

下载链路不稳定时，先用流水灯例程确认 Vivado、Digilent 驱动、JTAG 和板卡供电是否正常。
