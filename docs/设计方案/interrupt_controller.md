# 中断控制器设计方案

## 目标

本模块实现一个简化 PLIC 风格的机器外部中断控制器，作为内存映射 I/O 设备挂载到数据总线译码器后。CPU 后续可以通过 `lw/sw` 配置中断源优先级、使能位和阈值，并通过 Claim/Complete 流程处理中断。

当前实现范围：

```text
支持 16 个中断源，ID 0 保留
支持 priority / pending / enable / threshold / claim-complete 寄存器
输出 meip，表示存在可服务的机器外部中断
```

暂不实现 RISC-V CSR 侧的 `mie/mstatus/mcause/mtvec` 异常入口逻辑；CPU 是否响应 `meip` 由 CPU 负责人后续接入。

## 地址映射

中断控制器挂载在：

```text
0x8100_0000 - 0x8120_0007
```

数据总线译码器在该窗口内拉高 `intc_cs`，并把 CPU 的 `dmem_*` 事务转发给 `interrupt_controller`。

| 地址 | 寄存器 | 访问 | 说明 |
| --- | --- | --- | --- |
| `0x8100_0004 + 4*ID` | `PRIORITY[ID]` | R/W | 中断源优先级，ID 1-15 有效，低 3 位有效 |
| `0x8100_1000` | `PENDING` | R | 当前待决中断位 |
| `0x8100_2000` | `ENABLE` | R/W | 中断源使能位，bit 0 强制保留 |
| `0x8120_0000` | `THRESHOLD` | R/W | 优先级阈值，低 3 位有效 |
| `0x8120_0004` | `CLAIM/COMPLETE` | R/W | 读返回最高优先级待处理中断 ID；写 ID 表示处理完成 |

未定义偏移、非 32 位字访问、写 `PENDING` 均返回 `dmem_fault=1`。

## 仲裁规则

中断控制器每周期组合计算当前最高优先级中断：

```text
pending = irq_sources & ~claimed
候选条件 = pending[id] && enable[id] && priority[id] > threshold
```

若多个候选源同时存在，选择优先级最高者；当前实现中相同优先级时保留先出现的较小 ID。

当存在候选源时：

```text
meip = 1
dmem_irq = meip
```

`dmem_irq` 是为了符合统一设备接口保留；系统真正给 CPU 的机器外部中断线使用 `meip`。

## Claim/Complete 流程

1. CPU 读 `CLAIM/COMPLETE`。
2. 控制器返回当前最高优先级待处理中断 ID。
3. 被 claim 的 ID 进入 `claimed` 状态，不再重复出现在 pending 中。
4. CPU 完成服务后向同一地址写回该 ID。
5. 控制器清除该 ID 的 claimed 状态；如果外设中断电平仍为 1，该源会再次进入 pending。

因此外设侧应在软件服务完成后撤销自己的 `irq_sources[id]`，否则该中断会再次触发。

## 与 I/O 设备的关系

当前 I/O 设备模块均已经保留 `dmem_irq` 输出。后续系统集成时可按 A 的架构表连接：

```text
io_buttons.dmem_irq  -> irq_sources[8]
io_switches.dmem_irq -> irq_sources[10]
PS/2.dmem_irq        -> irq_sources[2]
```

本次 C 分支中的 SW/BTN 交互演示仍采用 CPU 轮询方式，因此 `io_buttons` 和 `io_switches` 的 `dmem_irq` 暂时恒为 0。中断控制器本身已经可以通过 testbench 注入 `irq_sources` 独立验证。

## 验证

仿真命令：

```powershell
& 'D:\iverilog\bin\iverilog.exe' -g2012 -s tb_interrupt_controller -o sim\interrupt_controller.vvp src\interrupt_controller.v sim\tb_interrupt_controller.v
& 'D:\iverilog\bin\vvp.exe' sim\interrupt_controller.vvp
```

期望输出：

```text
PASS: interrupt controller passed
```

覆盖场景：

```text
priority / enable / threshold 写入和读回
多个中断源同时 pending 时选择最高优先级
claim 后同一源不重复出现
complete 后可重新接受该源
threshold 屏蔽低优先级源
pending 寄存器暴露当前源状态
非法偏移返回 fault
```
