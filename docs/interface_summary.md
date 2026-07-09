内存模块接口汇总

本文档供系统集成负责人快速查阅各内存模块的端口定义。


1. ram.v（统一RAM底层模块）

参数：
ADDR_WIDTH：默认值12，地址位宽，支持2的12次方即4096个存储单元
DATA_WIDTH：默认值32，数据位宽

端口列表：
clk：输入，位宽1，时钟信号，上升沿有效
rst_n：输入，位宽1，异步复位，低电平有效
read_en：输入，位宽1，读使能，高电平有效
write_en：输入，位宽1，写使能，高电平有效
addr：输入，位宽32，字节地址，实际使用addr右移2位作为索引
write_data：输入，位宽DATA_WIDTH，写数据
read_data：输出，位宽DATA_WIDTH，读数据，组合逻辑输出
ready：输出，位宽1，就绪信号，当前版本恒为1


2. imem.v（指令存储器，只读）

参数：
IMEM_DEPTH：默认值4096，存储深度

端口列表：
clk：输入，位宽1，时钟信号
rst_n：输入，位宽1，异步复位，低电平有效
read_en：输入，位宽1，读使能
addr：输入，位宽32，字节地址
instr_out：输出，位宽32，读取的指令数据
ready：输出，位宽1，就绪信号，恒为1

内部实现说明：
例化ram模块，写使能固定为0，实现只读功能。
instr_out直接连接ram的read_data输出。


3. dmem.v（数据存储器，读写）

参数：
DMEM_DEPTH：默认值4096，存储深度

端口列表：
clk：输入，位宽1，时钟信号
rst_n：输入，位宽1，异步复位，低电平有效
read_en：输入，位宽1，读使能
write_en：输入，位宽1，写使能
addr：输入，位宽32，字节地址
write_data：输入，位宽32，写数据
read_data：输出，位宽32，读数据
ready：输出，位宽1，就绪信号，恒为1

内部实现说明：
例化ram模块，所有信号直接透传。
read_data直接连接ram的read_data输出。


4. cache.v（直接映射Cache）

参数：
NUM_LINES：默认值8，Cache行数
INDEX_WIDTH：默认值3，索引位宽

端口列表：
clk：输入，位宽1，时钟信号
rst_n：输入，位宽1，异步复位，低电平有效
read_en：输入，位宽1，读使能
write_en：输入，位宽1，写使能
addr：输入，位宽32，字节地址
write_data：输入，位宽32，写数据
read_data：输出，位宽32，读数据（寄存器输出，延迟1周期）
ready：输出，位宽1，就绪信号，恒为1
hit：输出，位宽1，命中指示信号（寄存器输出）
miss：输出，位宽1，缺失指示信号（寄存器输出）
hit_count：输出，位宽32，命中次数统计
miss_count：输出，位宽32，缺失次数统计

内部结构说明：
Cache存储阵列包含三个数组：cache_data（32位宽，8深）、cache_tag（32位宽，8深）、cache_valid（1位宽，8深）。
地址分解：Index为addr的第3位到第2位，共3位；Tag为addr的第31位到第4位，共28位。
命中判断：组合逻辑，cache_valid[index]为1且cache_tag[index]等于tag时命中。