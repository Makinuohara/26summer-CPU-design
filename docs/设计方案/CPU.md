# CPU 子系统设计方案

## 1. 设计目标

CPU 子系统负责实现阶段二任务中的 D 方向：RISC-V32I 子集 CPU、流水线机制、CPI/频率/吞吐量评估，以及与系统结构、内存子系统、板载 I/O 的干净接口。

本方案遵循 `docs/设计方案/architect.md` 中已经确定的系统架构：

1. 系统采用哈佛结构，CPU 分别通过指令总线和数据总线访问指令存储器、数据存储器和内存映射 I/O。
2. 指令总线、数据总线统一使用 `req/ack` 握手，不假设存储器或外设一定单周期响应。
3. CPU 不直接连接 LED、拨码开关、数码管等板载外设，全部 I/O 访问通过数据总线地址映射完成。
4. 任意 CPU 实现，包括单周期、多周期、流水线，都必须遵循统一 CPU 顶层端口。

## 2. 设计边界

### 2.1 CPU 负责内容

| 模块         | 责任                                                    |
| ------------ | ------------------------------------------------------- |
| 取指单元     | 维护 PC，发起`imem` 取指请求，处理取指等待            |
| 译码单元     | 解析指令字段，生成控制信号，读取寄存器                  |
| 执行单元     | ALU 运算、分支比较、跳转目标计算                        |
| 访存单元     | 对`lw/sw` 等指令发起数据访问，请求经过 CPU 内部 D-Cache 与 MMIO 旁路后再访问外部总线 |
| 写回单元     | 将 ALU、访存、`PC+4`、立即数等结果写回寄存器          |
| 冒险处理     | 数据前递、load-use 暂停、分支/跳转冲刷                  |
| 性能统计     | 统计 cycle、instret、stall、flush 等指标                |
| CSR/中断控制 | 维护机器态 CSR、trap 入口、`mret` 返回和中断排空流程 |
| 内置 D-Cache | 对主存地址访问提供缓存加速，对 MMIO 地址直接旁路        |

### 2.2 CPU 不负责内容

| 内容                            | 归属             |
| ------------------------------- | ---------------- |
| 指令存储器具体容量和初始化方式  | B：内存子系统    |
| 数据存储器具体容量和后端延迟 | B：内存子系统    |
| LED、SW、数码管、按键等外设实现 | C：板载 I/O 接口 |
| 数据总线地址译码和 SoC 集成     | A：系统结构设计  |
| FPGA 顶层管脚约束               | A/C 联合维护     |

CPU 仍只对 SoC 输出标准 `imem_*`、`dmem_*` 总线信号，但当前版本已经把 D-Cache 上移到 CPU 内部：对主存地址走缓存，对 MMIO 地址不缓存直接旁路。

## 3. CPU 顶层接口

### 3.1 推荐顶层模块

阶段二新增流水线 CPU 顶层命名为：

```verilog
module pipeline_cpu_top #(
    parameter DCACHE_LINES = 16,
    parameter DCACHE_LINE_WORDS = 4
) (
    input  wire        clk,
    input  wire        rst_n,

    output wire        imem_req,
    output wire [31:0] imem_addr,
    input  wire        imem_ack,
    input  wire [31:0] imem_data,

    output wire        dmem_req,
    output wire [31:0] dmem_addr,
    output wire        dmem_we,
    output wire [31:0] dmem_wdata,
    output wire [1:0]  dmem_width,
    input  wire        dmem_ack,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_fault,

    input  wire        meip,
    input  wire        mtip,
    input  wire        msip,

    output wire [31:0] debug_pc,
    output wire [31:0] debug_cycle,
    output wire [31:0] debug_instret,
    output wire [31:0] debug_stall,
    output wire [31:0] debug_flush
);
```

该端口集在 `architect.md` 的基础上增加了调试/性能统计输出。集成到 `soc_top` 时，调试输出可接入性能计数器地址窗口，也可仅用于仿真。

其中：

- `DCACHE_LINES`：CPU 内部 D-Cache 的行数
- `DCACHE_LINE_WORDS`：每行包含的 32 位字数

这两个参数只影响主存数据路径，不改变 CPU 对外总线接口。

### 3.2 端口说明

| 端口              | 方向 | 位宽 | 说明                                |
| ----------------- | ---- | ---- | ----------------------------------- |
| `clk`           | in   | 1    | 全局时钟，上升沿采样                |
| `rst_n`         | in   | 1    | 低有效复位                          |
| `imem_req`      | out  | 1    | 取指请求                            |
| `imem_addr`     | out  | 32   | 取指字节地址，要求 4 字节对齐       |
| `imem_ack`      | in   | 1    | 指令存储器响应                      |
| `imem_data`     | in   | 32   | 取回的 32 位指令                    |
| `dmem_req`      | out  | 1    | 数据访存请求                        |
| `dmem_addr`     | out  | 32   | 数据访存字节地址                    |
| `dmem_we`       | out  | 1    | 写使能，1 表示写，0 表示读          |
| `dmem_wdata`    | out  | 32   | 写入数据                            |
| `dmem_width`    | out  | 2    | `00` 字，`01` 半字，`10` 字节 |
| `dmem_ack`      | in   | 1    | 数据总线响应                        |
| `dmem_rdata`    | in   | 32   | 数据总线读回原始 32 位数据          |
| `dmem_fault`    | in   | 1    | 地址错误或设备访问错误              |
| `meip`          | in   | 1    | 机器态外部中断待决                  |
| `mtip`          | in   | 1    | 机器态定时器中断待决                |
| `msip`          | in   | 1    | 机器态软件中断待决                  |
| `debug_pc`      | out  | 32   | 当前提交或取指 PC，用于调试         |
| `debug_cycle`   | out  | 32   | 周期计数                            |
| `debug_instret` | out  | 32   | 已提交指令数                        |
| `debug_stall`   | out  | 32   | 流水线暂停次数                      |
| `debug_flush`   | out  | 32   | 流水线冲刷次数                      |

### 3.3 复位行为

复位期间 CPU 输出保持以下默认值：

| 信号           | 复位值          |
| -------------- | --------------- |
| `imem_req`   | `0`           |
| `imem_addr`  | `0x0000_0000` |
| `dmem_req`   | `0`           |
| `dmem_addr`  | `0x0000_0000` |
| `dmem_we`    | `0`           |
| `dmem_wdata` | `0x0000_0000` |
| `dmem_width` | `2'b00`       |
| `debug_*`    | `0`           |

复位释放后，PC 从 `0x0000_0000` 开始取指。

## 4. 指令集范围

### 4.1 基础必须支持

阶段二 CPU 至少应保持当前基础 CPU 已支持的指令：

| 类型         | 指令                                       |
| ------------ | ------------------------------------------ |
| R 型算术逻辑 | `add`、`sub`、`and`、`or`、`xor` |
| I 型算术逻辑 | `addi`、`andi`、`ori`、`xori`      |
| Load         | `lw`                                     |
| Store        | `sw`                                     |
| Branch       | `beq`、`bne`                           |
| Jump         | `jal`                                    |

### 4.2 阶段二建议扩展

为满足进阶层次“RISC-V32I 子集实现”的要求，建议优先补齐以下常用 RV32I 指令：

| 类型          | 指令                                                    | 优先级 |
| ------------- | ------------------------------------------------------- | ------ |
| 移位          | `sll`、`srl`、`sra`、`slli`、`srli`、`srai` | 高     |
| 比较          | `slt`、`sltu`、`slti`、`sltiu`                  | 高     |
| 上立即数      | `lui`、`auipc`                                      | 高     |
| 跳转          | `jalr`                                                | 高     |
| 分支          | `blt`、`bge`、`bltu`、`bgeu`                    | 高     |
| 字节/半字访存 | `lb`、`lh`、`lbu`、`lhu`、`sb`、`sh`        | 中     |

### 4.3 整数乘除法扩展

当前实现 RV32M 的两个核心操作：

| 指令 | funct7 | funct3 | 语义 |
|---|---|---|---|
| `mul` | `0000001` | `000` | 返回有符号乘积低 32 位 |
| `div` | `0000001` | `100` | 32 位有符号除法 |

两条指令复用 EX 阶段 ALU 通路。除数为 0 时 `div` 返回 `0xffff_ffff`；`0x8000_0000 / -1` 返回 `0x8000_0000`。当前为组合单周期实现，结构直观但会拉长 EX 关键路径；后续高频优化应改为多周期迭代单元，并向冒险控制提供 busy/ready stall 握手。

### 4.4 暂不纳入范围

| 内容 | 说明 |
|---|---|
| 完整 `M` 扩展 | 暂不实现 `mulh/mulhsu/mulhu/divu/rem/remu` |
| `F/D` 扩展 | 浮点运算不纳入当前 CPU 主线 |
| 完整异常体系 | `ecall/ebreak`、非法指令、精确异常 `mtval` 等后续扩展 |
| 压缩指令 `C` | 当前取指按 32 位固定长度处理 |

## 5. 流水线结构

### 5.1 五级流水

流水线 CPU 采用经典五级结构：

```text
IF  ->  ID  ->  EX  ->  MEM  ->  WB
取指    译码    执行     访存     写回
```

各级职责如下：

| 阶段 | 主要功能                                           |
| ---- | -------------------------------------------------- |
| IF   | PC 寄存器、取指请求、下一 PC 选择                  |
| ID   | 指令字段解析、控制信号生成、寄存器读取、立即数生成 |
| EX   | ALU 运算、分支比较、跳转目标计算、前递选择         |
| MEM  | 数据总线访问、load/store 等待、访存异常接收        |
| WB   | 写回数据选择、寄存器写回、指令提交统计             |

流水线寄存器：

| 寄存器         | 连接阶段 | 内容                                            |
| -------------- | -------- | ----------------------------------------------- |
| `if_id_reg`  | IF/ID    | `pc`、`pc_plus4`、`instr`、valid          |
| `id_ex_reg`  | ID/EX    | 操作数、立即数、rd/rs、控制信号、valid          |
| `ex_mem_reg` | EX/MEM   | ALU 结果、store 数据、分支结果、访存控制、valid |
| `mem_wb_reg` | MEM/WB   | ALU 结果、load 数据、写回控制、valid            |

### 5.2 推荐源码拆分

CPU 子系统建议独立放在：

```text
src/cpu/pipeline/
  pipeline_cpu_top.v
  pipeline_if_stage.v
  pipeline_id_stage.v
  pipeline_ex_stage.v
  pipeline_mem_stage.v
  pipeline_wb_stage.v
  if_id_reg.v
  id_ex_reg.v
  ex_mem_reg.v
  mem_wb_reg.v
  pipeline_control_unit.v
  hazard_unit.v
  forwarding_unit.v
  perf_counter.v
```

当前 `src/*.v` 中的基础单周期 CPU 保留为 baseline。流水线 CPU 不直接覆盖基础版，避免破坏已有仿真和上板结果。

## 6. 总线握手策略

### 6.1 指令总线

IF 阶段发起取指：

```text
imem_req=1
imem_addr=pc
```

当 `imem_ack=0` 时，IF 阶段必须保持 `imem_req` 和 `imem_addr` 稳定，同时暂停 PC 更新和 IF/ID 流水寄存器写入。

当 `imem_ack=1` 时，`imem_data` 被采样进入 IF/ID 寄存器。

#### 6.1.1 本轮修正的取指控制线路

为解决板级联调中出现的“回跳后取错指令、`lw` 结果不再更新”的问题，CPU 取指控制增加了两条约束：

1. `imem_wait` 只阻塞前端取指，不再阻塞 EX/MEM/WB 老指令的继续前推。
2. 当 EX 阶段产生分支、`jal/jalr` 或 `mret/trap` 重定向时，若旧 PC 的取指请求仍在飞行，则该响应在返回时必须丢弃，不能再写入 IF/ID。

对应到当前实现：

```text
pipeline_stall = dmem_wait || load_use_stall
perf_stall     = imem_wait || pipeline_stall
```

这意味着：

1. 数据访存等待、load-use 仍然冻结后端流水线。
2. 单纯取指等待只会让 IF/ID 暂时没有新指令，不会把已经进入 EX/MEM/WB 的指令错误重放。
3. 控制流重定向时，CPU 通过 `discard_imem_resp` 丢弃悬空的旧取指响应，保证回跳后重新从新 PC 发起取指。

新增线路可概括为：

```text
redirect_exec / enter_interrupt_drain
            |
            +--> 更新 pc = redirect_pc
            |
            +--> 若旧取指未返回，则置位 discard_imem_resp
                                 |
                                 +--> 下一次 imem_ack 到来时丢弃该响应
                                 +--> 保留 redirect_pc，重新取正确目标指令
```

这条修正主要影响 IF 控制与控制冒险处理，不改变寄存器堆、ALU、访存宽度和 CSR 指令语义。

### 6.2 数据总线

当前实现中，CPU 的数据访问先在核心内部做一次地址分类：

```text
addr < 0x0800_0000   -> 视为主存访问，走 CPU 内部 D-Cache
addr >= 0x0800_0000  -> 视为 MMIO 访问，直接旁路到外部数据总线
```

因此对外部 SoC 而言，CPU 仍然只暴露一套：

```text
dmem_req / dmem_addr / dmem_we / dmem_wdata / dmem_width
```

但内部已经形成两条不同的处理路径：

1. 主存路径：`MEM stage -> internal dcache -> dmem backend`
2. MMIO 路径：`MEM stage -> dmem_bus_decoder -> io/intc`

这样做的好处是：

- cache 不再和后端主存封装在同一个模块中
- 主存层次和 I/O 层次在 CPU 侧就已分流
- 更符合“cache 作为 CPU 近端缓存”的设计本意

### 6.2.1 当前 D-Cache 集成策略

当前 CPU 内置的是一层 D-Cache，基本策略为：

- 仅缓存主存地址空间
- MMIO 永远不进入 cache
- 保持外部 `dmem_*` 端口不变，便于 SoC 顶层和仿真夹具复用

因此阶段二之后的结构已经从：

```text
CPU -> dmem(含cache) -> backend memory
```

调整为：

```text
CPU(含dcache) -> dmem(纯后端主存)
CPU -> MMIO decoder -> io/intc
```

MEM 阶段遇到 load/store 时发起数据访问：

```text
dmem_req=1
dmem_addr=ex_mem_alu_result
dmem_we=store_en
dmem_wdata=store_data
dmem_width=访问宽度
```

当 `dmem_ack=0` 时，MEM 阶段及其之前的流水线阶段整体暂停，保证该访存指令不被后续指令覆盖。

当 `dmem_ack=1` 时：

1. load 指令采样 `dmem_rdata`，送入 MEM/WB。
2. store 指令认为写入完成，可以提交。
3. 若 `dmem_fault=1`，当前阶段先记录 fault；最小实现可将其作为停止/调试标志，完整实现再进入异常处理。

### 6.3 访存宽度

`dmem_width` 定义与架构文档保持一致：

```text
2'b00: word
2'b01: halfword
2'b10: byte
2'b11: reserved
```

数据总线返回原始 32 位数据，CPU 在 WB 阶段或 MEM 阶段根据 load 指令类型完成符号扩展或零扩展。

## 7. 冒险处理

### 7.1 数据前递

为减少无效暂停，EX 阶段应支持来自后续流水级的结果前递：

| 来源                  | 目标       | 用途                   |
| --------------------- | ---------- | ---------------------- |
| EX/MEM.ALU result     | EX.rs1/rs2 | 解决 ALU 指令紧邻相关  |
| MEM/WB.writeback data | EX.rs1/rs2 | 解决间隔一条以上的相关 |

前递优先级：

```text
EX/MEM 优先于 MEM/WB
```

### 7.2 load-use 暂停

当 ID 阶段指令读取的 `rs1/rs2` 依赖 EX 阶段 load 指令的 `rd` 时，load 数据尚未返回，必须插入 1 个 bubble：

```text
id_ex_mem_read &&
id_ex_rd != 0 &&
(id_ex_rd == if_id_rs1 || id_ex_rd == if_id_rs2)
```

处理动作：

1. PC 保持不变。
2. IF/ID 保持不变。
3. ID/EX 写入空操作控制信号。
4. `debug_stall` 计数加 1。

### 7.3 控制冒险

分支和跳转建议在 EX 阶段确定目标。若跳转成立：

1. PC 更新为分支/跳转目标。
2. IF/ID 和 ID/EX 中的错误路径指令置 invalid 或注入 NOP。
3. `debug_flush` 计数加 1 或按冲刷级数累加。

`jalr` 目标为：

```text
(rs1 + imm) & 32'hffff_fffe
```

### 7.4 结构冒险

系统采用哈佛结构，指令总线和数据总线分离，正常情况下不存在取指和访存争用同一总线的结构冒险。若 B 组后续在底层将指令和数据统一到同一物理 RAM 或 DDR 控制器，则由内存子系统通过 `ack` 等待体现，CPU 只需按握手暂停。

## 8. 控制信号设计

ID 阶段生成的控制信号随流水线向后传递：

| 控制信号          | 作用阶段 | 说明                     |
| ----------------- | -------- | ------------------------ |
| `alu_op`        | EX       | 选择 ALU 运算            |
| `alu_src1_sel`  | EX       | 选择`rs1` 或 PC        |
| `alu_src2_sel`  | EX       | 选择`rs2` 或立即数     |
| `branch_type`   | EX       | 分支类型                 |
| `jump_type`     | EX       | `jal`/`jalr`         |
| `mem_read`      | MEM      | 发起 load                |
| `mem_write`     | MEM      | 发起 store               |
| `mem_width`     | MEM      | byte/halfword/word       |
| `load_unsigned` | MEM/WB   | 控制 load 零扩展         |
| `reg_write`     | WB       | 是否写回 rd              |
| `wb_sel`        | WB       | ALU、MEM、PC+4、IMM 选择 |

推荐 `wb_sel` 编码：

| 编码      | 来源                      |
| --------- | ------------------------- |
| `2'b00` | ALU result                |
| `2'b01` | memory load data          |
| `2'b10` | `PC+4`                  |
| `2'b11` | immediate /`lui` result |

## 9. 性能统计

CPU 内部设置性能计数器，用于 D 方向验收的 CPI/stall/flush 评估。

| 计数器      | 递增条件                                        |
| ----------- | ----------------------------------------------- |
| `cycle`   | 复位释放后每个周期加 1                          |
| `instret` | WB 阶段有 valid 指令成功提交                    |
| `stall`   | 因 load-use、取指等待、访存等待等导致流水线暂停 |
| `flush`   | 因分支、跳转、异常等清空错误路径指令            |

CPI 计算：

```text
CPI = cycle / instret
```

吞吐量估算：

```text
IPS = Fmax / CPI
```

若 `instret=0`，仿真或显示逻辑应避免除零，只输出原始计数。

## 10. 异常与中断策略

当前版本已经补齐机器态中断主链路，支持 `meip/mtip/msip -> CSR 判定 -> trap -> mret`。

### 10.1 当前已实现

| 项目 | 当前策略 |
| ---- | -------- |
| `mstatus` | 实现 `MIE/MPIE` 位，trap 时关闭中断，`mret` 恢复 |
| `mie` | 实现 `MEIE/MTIE/MSIE` 使能位 |
| `mip` | 由外部 `meip/mtip/msip` 实时映射生成 |
| `mtvec` | 软件可通过 CSR 指令配置 trap 入口 |
| `mepc` | trap 时保存返回 PC，`mret` 跳回 |
| `mcause` | 记录中断原因，当前支持机器外部/定时器/软件中断 |
| CSR 指令 | 支持 `csrrw/csrrs/csrrc/csrrwi/csrrsi/csrrci` |
| 返回指令 | 支持 `mret` |

### 10.2 当前 trap 流程

1. CSR 先根据 `mstatus.MIE` 与 `mie` 掩码判断是否存在待响应中断。
2. CPU 不直接打断当前在飞指令，而是进入 interrupt drain 状态，停止继续取入新指令。
3. 已在流水线中的旧指令继续前推并提交，直到流水线排空。
4. 排空后写入 `mepc/mcause`，清除 `MIE`，跳转到 `mtvec`。
5. trap handler 执行 `mret` 后，CPU 从 `mepc` 恢复，并把 `MPIE` 还原回 `MIE`。

### 10.3 仍未覆盖

1. `ecall`、`ebreak`、非法指令、未对齐访问等同步异常。
2. `mtval` 等更完整的特权寄存器。
3. 更细粒度的精确异常策略，目前重点覆盖阶段二所需的机器态中断联调。

## 11. 与现有基础 CPU 的关系

当前基础 CPU 是单周期实现，模块位于 `src/*.v`。它已经可以完成基础 smoke test，适合作为阶段二对照版本。

流水线版本不直接替换现有 `cpu_top.v`，而是新增 `pipeline_cpu_top.v`。后续由 A 组在 `soc_top` 中选择接入哪个 CPU：

```text
基础对照：cpu_top
阶段二：pipeline_cpu_top
```

为了便于对比，建议保留两套仿真：

| 仿真                      | 目标                                |
| ------------------------- | ----------------------------------- |
| `tb_cpu_top.v`          | 验证基础单周期 CPU 未被破坏         |
| `tb_pipeline_cpu_top.v` | 验证流水线 CPU 功能、冒险和性能统计 |

## 12. 验收测试计划

### 12.1 功能测试

| 测试                    | 覆盖内容                                    |
| ----------------------- | ------------------------------------------- |
| `pipeline_smoke`      | `addi/add/sw/lw/beq/jal` 主链路           |
| `pipeline_logic`      | `and/or/xor/andi/ori/xori`                |
| `pipeline_shift_cmp`  | 移位和比较指令                              |
| `pipeline_branch`     | `beq/bne/blt/bge/bltu/bgeu/jal/jalr`      |
| `pipeline_load_store` | `lw/sw`，后续扩展 `lb/lh/lbu/lhu/sb/sh` |
| `pipeline_hazard`     | 前递、load-use stall、分支 flush            |

### 12.2 集成测试

| 测试                    | 通过标准                                      |
| ----------------------- | --------------------------------------------- |
| CPU + imem              | CPU 能通过`imem` 握手取指并运行程序         |
| CPU + dmem              | CPU 能通过`dmem` 握手完成 load/store        |
| CPU + memory-mapped I/O | CPU 通过`lw/sw` 访问 LED/SW/数码管地址      |
| CPU + interrupt         | CPU 能响应 `meip/mtip/msip`，进入 trap 并通过 `mret` 返回 |
| CPU + SoC               | `soc_top` 集成后仿真结果与单独 CPU 仿真一致 |

### 12.3 性能对比

阶段二报告中建议给出：

| 指标        | 单周期 CPU | 流水线 CPU |
| ----------- | ---------- | ---------- |
| Vivado Fmax | 待测       | 待测       |
| cycle       | 待测       | 待测       |
| instret     | 待测       | 待测       |
| CPI         | 待测       | 待测       |
| stall       | 不适用或 0 | 待测       |
| flush       | 不适用或 0 | 待测       |
| LUT/FF/BRAM | 待测       | 待测       |

## 13. D 方向最小交付清单

| 交付物          | 路径建议                                |
| --------------- | --------------------------------------- |
| CPU 设计方案    | `docs/设计方案/CPU.md`                |
| 流水线 CPU 顶层 | `src/cpu/pipeline/pipeline_cpu_top.v` |
| CSR/中断模块    | `src/cpu/pipeline/pipeline_csr_unit.v` |
| 流水线阶段模块  | `src/cpu/pipeline/*_stage.v`          |
| 冒险处理模块    | `src/cpu/pipeline/hazard_unit.v`      |
| 前递模块        | `src/cpu/pipeline/forwarding_unit.v`  |
| 性能计数器      | `src/cpu/pipeline/perf_counter.v`     |
| 流水线仿真      | `sim/tb_pipeline_cpu_top.v`           |
| 中断仿真        | `sim/tb_pipeline_cpu_irq.v`           |
| 流水线文件列表  | `scripts/filelist_pipeline.f`         |

## 14. 实施顺序

建议按以下顺序推进：

1. 固定 `pipeline_cpu_top` 端口，先提供空壳模块，方便 A/B/C 并行集成。
2. 复用现有 `regfile`、`imm_gen`、`alu`、`branch_unit` 思路，完成无冒险版本流水线。
3. 支持基础 smoke test 指令，跑通 `addi/add/sw/lw/beq/jal`。
4. 增加前递和 load-use stall，跑通 hazard 测试。
5. 扩展常用 RV32I 指令。
6. 接入性能计数器，输出 CPI/stall/flush 数据。
7. 与 `soc_top`、`imem/dmem`、I/O 地址映射联调。
