
# 存储子系统设计方案

## 1. 设计目标

存储子系统负责提供阶段二 SoC 的指令存储、数据存储和缓存能力，并严格遵循
`docs/设计方案/architect.md` 中定义的总线接口契约。

本版实现目标不是“最小能跑”，而是可直接参与后续系统联调的成熟版本：

1. 指令侧提供独立 `imem_req/imem_ack/imem_data` 握手接口。
2. 数据侧提供可挂到总线译码器后的标准设备接口。
3. 数据存储器支持 `word/half/byte` 访问和写掩码。
4. D-Cache 提供真实命中/失效行为，不再使用假数据占位。
5. 所有读返回值遵循架构文档要求：`dmem_rdata` 返回原始 32 位字。

## 2. 模块划分

建议源码结构如下：

```text
src/memory/
  memory_array.v
  imem.v
  dmem_store.v
  dcache.v
  dmem_cached_device.v
  memory_subsystem.v
```

各模块职责：

| 模块 | 责任 |
| --- | --- |
| `memory_array.v` | 底层字寻址存储阵列，支持字节写使能 |
| `imem.v` | 指令存储器，服务 CPU 独立取指通路 |
| `dmem_store.v` | 数据存储后端，处理真实字节/半字/字写入 |
| `dcache.v` | 直接映射 D-Cache，处理命中、失效、填充 |
| `dmem_cached_device.v` | 对外暴露为总线设备的缓存数据存储器 |
| `memory_subsystem.v` | 独立联调用封装，同时输出 IMEM/DMEM 两类接口 |

## 3. 指令存储器

### 3.1 接口

`imem.v` 使用以下接口：

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

1. `imem_addr` 必须按 4 字节对齐。
2. 当 `RESP_LATENCY=0` 时，取指可单周期完成。
3. 当 `RESP_LATENCY>0` 时，`imem` 在内部记录请求地址，等待若干周期后返回 `ack`。
4. 地址越界或未对齐时返回 `NOP (32'h00000013)`，不主动 fault。

这样既可用于 BRAM 单周期模式，也可模拟后续外部存储等待周期。

## 4. 数据后端

### 4.1 原始存储模型

`dmem_store.v` 是数据存储的真实后端，不对读数据做任何符号扩展。

读语义：

- 无论指令是 `lb/lh/lw/lbu/lhu` 中的哪一种，后端都返回地址所在字的完整 32 位内容。
- 由 CPU 根据 `addr[1:0]` 和指令类型自行提取并做符号/零扩展。

写语义：

- `word`：四字节全写
- `half`：根据 `addr[1]` 写低半字或高半字
- `byte`：根据 `addr[1:0]` 写对应字节

### 4.2 错误处理

`dmem_store.v` 在以下情况下置 `fault=1`：

1. 访问超出配置的物理存储深度
2. `word` 访问未按字对齐
3. `half` 访问未按半字对齐

## 5. D-Cache 设计

### 5.1 组织方式

当前实现采用：

- 直接映射（direct-mapped）
- 一组一行
- 每行 `LINE_WORDS` 个 32 位字
- 写直达（write-through）
- 写不分配（write-no-allocate）

### 5.2 读命中

若 `valid[index]==1` 且 `tag` 匹配：

1. 直接返回缓存行内对应字
2. `dmem_ack=1`
3. 不访问后端存储

### 5.3 读失效

若缓存失效：

1. 计算缓存行基址
2. 逐字向 `dmem_store` 发起读取
3. 读取完成后写入 cache line
4. 返回请求字并置 `dmem_ack=1`

### 5.4 写策略

写请求统一写入后端：

- 命中：同时更新 cache line 中对应字节
- 失效：只写后端，不分配新 cache line

该策略实现简单、行为明确，适合课程阶段二系统联调。

## 6. 总线设备接口

`dmem_cached_device.v` 按 `architect.md` 的设备契约实现：

```verilog
module dmem_cached_device (
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

其中：

- `dmem_cs==0` 时该设备保持空闲
- `dmem_irq` 恒为 `0`
- 可直接作为总线译码器 `cs[0]` 指向的数据存储设备

## 7. 独立联调封装

`memory_subsystem.v` 为 CPU 单独联调提供一个统一封装：

1. 指令侧直连 `imem`
2. 数据侧直连 `dmem_cached_device`

这样在 SoC 总线尚未完全接入前，CPU 团队可以先完成独立联调；
后续系统集成时，只需保留 `imem.v` 和 `dmem_cached_device.v` 两个边界模块即可。

## 8. 与系统架构的匹配关系

| 架构要求 | 当前实现方式 |
| --- | --- |
| 哈佛结构 | `imem` 与 `dmem` 分离 |
| `req/ack` 握手 | `imem`、`dmem_store`、`dcache` 全部支持等待周期 |
| 数据总线原始 32 位返回 | `dmem_store` / `dcache` 不做扩展 |
| Cache 使用 BRAM 思路 | 使用字阵列+缓存行模型 |
| 数据存储器为总线下挂设备 | `dmem_cached_device.v` 暴露标准设备接口 |

## 9. 后续可扩展点

当前版本已经满足阶段二成熟联调需求，但仍预留以下扩展空间：

1. 指令存储器初始化改为由 bitstream/COE/MIF 文件加载
2. D-Cache 增加写回（write-back）和脏位
3. 增加 cache hit/miss 统计寄存器并通过总线映射输出
4. 对接 DDR 控制器，将 `dmem_store` 替换为更慢的外部主存接口
5. 增加 I-Cache，将 `imem` 的后端从 ROM 扩展为层次化存储
