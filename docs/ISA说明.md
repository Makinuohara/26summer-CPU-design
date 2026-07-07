# ISA 说明

本工程参照 RISC-V RV32I，只实现基础层次需要的真子集。寄存器为 32 个 32 位通用寄存器，`x0` 恒为 0。

## 指令子集

| 类型 | 指令 | 说明 |
| --- | --- | --- |
| R 型 | `add/sub/and/or/xor` | 两个寄存器操作数，结果写回 `rd` |
| I 型 | `addi/andi/ori/xori` | 一个寄存器和一个 12 位符号扩展立即数 |
| Load | `lw` | 从数据存储器读 32 位字 |
| Store | `sw` | 向数据存储器写 32 位字 |
| Branch | `beq/bne` | 相等或不等时 PC 相对跳转 |
| Jump | `jal` | PC 相对跳转，`rd` 写入 `PC+4` |

## 暂不支持

第一版暂不支持字节/半字访存、比较指令、移位指令、`jalr`、异常、中断和 CSR。后续扩展可以继续沿用当前的 `control_unit`、`alu_control` 和 `imm_gen`。
