本仓库是为2022年秋季学期的计算机系统实验课准备的，按计划将由3位同学完成这个项目

项目进度如下：

Oct 31 Liu 上传了初始环境，创建项目

Nov 3 Liu 按要求完成模10计数器的修改，完成模6和模60计数器。

Nov 5 Liu 通过了助教的小实验

Nov 30 Liu 查看VIVADO模拟中的错误，添加ORI和LIU相关的数据通路

Dec 5 Liu 添加  算数运算指令（add、addu、addi、addiu、sub、subu、slt、slti、sltu、sltiu），
                逻辑运算指令（or、xor），
                访存指令（lw、sw、lb、lbu、lh、lhu、sb、sh），
                移位指令（sll），
                分支跳转指令（jr、jal、bne、beq）
                的实现，通过1号点

Dec 9 Liu 添加指令和文件较为详细的解释，方便其他人查看指令的作用，以实现新的功能
          添加  算数运算指令（），
                逻辑运算指令（and、andi、nor），
                访存指令（），
                移位指令（sllv、sla、slav、srl、srlv），
                分支跳转指令（bnez、bgtz、blez、bltz、bgtzal、bgezal、j、jral）
                的相关判断，暂未实现通路


Dec 10 Li 同步了之前的模10计数器



Dec 10 Wang 修改了EX.v程序的对于id_to_ex_bus_r线路的注释错误


Dec 11 Liu  添加了/lib/decoder_2_4
            逻辑运算指令（and、andi、nor）
            的实现
            按照助教的提示添加访存处理


Dec 26 Liu  添加了缺失的逻辑运算指令的实现
            添加Stall，多过了1条指令。

            验证跳转指令，修改sel_alu_src，在验证8'd36中出现环路，模拟无法停止，
            猜测代码因为逻辑环路导致某个寄存器的值在一个时钟周期内反复横跳无法仿真，
            或者是一些奇奇怪怪的写回情况会导致仿真程序一直运行下去。
