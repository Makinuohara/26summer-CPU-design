# 存储子系统设计方案

## 1. 设计目标

存储子系统按照 `architect.md` 的系统约束重新收口为 3 个核心模块：

```text
src/memory/
  imem.v
  dmem.v
  cache.v
```

设计目标如下：

1. `imem` 服务 CPU 独立取指通路，遵循 `imem_req/imem_ack/imem_data` 握手。
2. `dmem` 作为数据总线下挂设备，接口风格与 I/O 模块保持一致，便于直接接入 `src/io/dmem_bus_decoder.v`。
3. `cache` 只负责缓存控制逻辑，不再额外拆出独立的 `store`/`subsystem`/`device wrapper` 文件。
4. `imem` 和 `dmem` 的公共存储后端逻辑抽取为共享内部层，不再在两个模块内重复实现。
5. `dmem_rdata` 始终返回原始 32 位字，由 CPU 自行完成字节/半字提取和符号扩展。

## 1.1 中断边界

存储子系统本身**不负责中断控制**。

具体边界如下：

1. `imem` 只是指令存储器，不产生中断。
2. `cache` 只是性能与访问时序优化层，不产生中断。
3. `dmem` 虽然作为数据总线下挂设备实现统一设备接口，但仅保留 `dmem_irq` 端口用于接口一致性，当前固定输出 `0`。
4. 真正的中断请求由 I/O 设备和 `interrupt_controller` 负责，存储模块不参与 `meip/mtip/msip` 的生成与仲裁。

因此，后续 CPU 中断联调时：

- `imem` 无需改动
- `cache` 无需改动
- `dmem` 仅保持 `dmem_irq = 1'b0`
- 中断路径应连接 `io_* -> interrupt_controller -> CPU(meip)`

## 2. 模块职责

| 模块 | 责任 |
| --- | --- |
| `imem.v` | 指令存储器，面向 CPU 取指总线 |
| `dmem.v` | 数据存储设备，面向数据总线译码器 |
| `cache.v` | 直接映射 D-Cache，处理 hit/miss/fill/write-through |

此外，`src/memory/memory_internal.vh` 提供共享内部模块 `memory_backend_core`，统一封装：

- 存储阵列
- 初始化加载
- 地址越界检测
- 可配置响应延迟
- 写掩码写入

## 3. `imem.v`

### 3.1 接口

```verilog
module imem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        imem_req,
    input  wire [31:0] imem_addr,
    output reg         imem_ack,
    output reg  [31:0] imem_data
);
```

### 3.2 行为

1. `imem` 不参与数据总线译码，保持哈佛结构中的独立指令通道。
2. 通过 `MEM_LATENCY` 参数支持单周期或多周期返回。
3. 地址未对齐或越界时返回 `NOP (32'h0000_0013)`。
4. 程序初始化通过 `INIT_FILE` 装载。

## 4. `dmem.v`

### 4.1 接口

`dmem.v` 按照数据总线设备规范实现，接口和 I/O 设备一致：

```verilog
module dmem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        dmem_cs,
    input  wire [31:0] dmem_addr,
    input  wire        dmem_we,
    input  wire [31:0] dmem_wdata,
    input  wire [1:0]  dmem_width,
    output wire        dmem_ack,
    output wire [31:0] dmem_rdata,
    output wire        dmem_fault,
    output wire        dmem_irq
);
```

### 4.2 与译码器的连接方式

`dmem.v` 不是 CPU 私有 RAM，而是通过 I/O 分支已经完成的总线译码器接入：

```text
CPU dmem_* -> dmem_bus_decoder -> mem_cs/mem_ack/mem_rdata/mem_fault -> dmem
```

也就是说，`dmem_bus_decoder` 的 `mem_*` 端口就是给 `dmem.v` 预留的：

```verilog
output wire mem_cs,
input  wire mem_ack,
input  wire [31:0] mem_rdata,
input  wire mem_fault
```

后续系统顶层集成时应连接为：

```verilog
.mem_cs(dmem_mem_cs),
.mem_ack(dmem_mem_ack),
.mem_rdata(dmem_mem_rdata),
.mem_fault(dmem_mem_fault)
```

然后由 `dmem.v` 实例输出对应返回信号。

### 4.3 内部结构

`dmem.v` 内部包含两部分：

1. 一个实例化的 `cache.v`
2. 一个共享后端 `memory_backend_core`

因此虽然对外交付仍然是三模块结构，但内部层次已经收敛为：

```text
数据总线 -> dmem -> cache -> memory_backend_core
```

### 4.4 访问语义

1. 支持 `word / half / byte` 写入
2. 读返回包含目标字节所在整字的原始 32 位值
3. 地址超出物理容量时返回 `dmem_fault=1`
4. `dmem_irq` 恒为 `0`

### 4.5 为什么 `dmem` 不做中断

`dmem` 的职责是“数据存储设备”，不是“事件源设备”。

它和 LED、按键、PS/2、中断控制器不同：

- `dmem` 不承载外部异步事件
- `dmem` 不需要向 CPU 报告“状态变化”
- `dmem` 的异常只通过 `dmem_fault` 表示访存错误，不通过中断表示

所以从系统架构上，存储模块不应自行拉起中断请求线。

## 5. `cache.v`

### 5.1 组织方式

当前缓存设计为：

- 直接映射
- 每行 `LINE_WORDS` 个 32 位字
- 写直达（write-through）
- 写不分配（write-no-allocate）

### 5.2 CPU/设备侧接口

`cache.v` 面向 `dmem.v` 的上层请求：

```verilog
req / addr / we / wdata / width
```

返回：

```verilog
ack / rdata / fault
```

### 5.3 后端侧接口

`cache.v` 不直接操作顶层总线，而是通过一组内部后端接口访问共享存储后端：

```verilog
mem_req / mem_we / mem_addr / mem_wdata / mem_wstrb
mem_ack / mem_rdata / mem_fault
```

### 5.4 行为

读命中：

1. 直接从缓存行返回
2. 不访问后端物理存储

读失效：

1. 计算 line base address
2. 逐字向后端请求
3. 填满整行
4. 返回请求字

写命中：

1. 更新缓存行对应字节
2. 同时写后端物理存储

写失效：

1. 不分配新 cache line
2. 直接写后端物理存储

## 6. 当前版本的边界

这版存储系统已经符合当前架构方向，但仍有明确边界：

1. `imem` 仍然是独立指令存储器，不和 I/O 共用数据总线
2. `dmem` 已经按“总线设备”形式实现，可直接挂到 `dmem_bus_decoder`
3. 存储模块不承担中断源职责，`dmem_irq` 当前固定为 `0`
4. cache 统计寄存器、DDR 后端替换、I-Cache 还未展开

## 7. 推荐集成方式

系统顶层建议这样接：

1. CPU 的 `imem_*` 直接连接 `imem.v`
2. CPU 的 `dmem_*` 先连接 `src/io/dmem_bus_decoder.v`
3. 译码器的 `mem_*` 端口再连接 `dmem.v`
4. 译码器其余 `sw/led/seg/btn/intc` 端口连接各 I/O 模块

这样 CPU、内存和 I/O 的职责边界是清楚的，后续联调也最稳定。
