`include "lib/defines.vh"
// 指令解码，同时读取寄存器
// IF/ID阶段可能会取出经符号扩展为32位的立即数和两个从寄存器中读取的数，放入ID/EX流水线寄存器

// 需要在该级进行指令译码
// 从寄存器中读取需要的数据
// 完成数据相关处理
// 生成发给EX段的控制信号

module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    
    output wire stallreq,

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,

    input wire ex_id,

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,
// 
    input wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus,
// 
    input wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus,

    output wire [`LoadBus-1:0] id_load_bus,
    output wire [`SaveBus-1:0] id_save_bus,

    output wire stallreq_for_bru,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus 
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;
    reg  flag;
    reg [31:0] buf_inst;

    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;

    wire ex_rf_we;
    wire [4:0] ex_rf_waddr;
    wire [31:0] ex_rf_wdata;
    
    wire mem_rf_we;
    wire [4:0] mem_rf_waddr;
    wire [31:0] mem_rf_wdata;

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0; 
            flag <= 1'b0;    
            buf_inst <= 32'b0;
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            flag <= 1'b0; 
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
            flag <= 1'b0; 
        end
        else if (stall[1]==`Stop && stall[2]==`Stop && ~flag) begin
            flag <= 1'b1;
            buf_inst <= inst_sram_rdata;
        end        
    end
    

    assign inst = ce ? flag ? buf_inst : inst_sram_rdata : 32'b0;
    assign {
        ex_rf_we,
        ex_rf_waddr,
        ex_rf_wdata
    } = ex_to_rf_bus;
    assign {
        mem_rf_we,
        mem_rf_waddr,
        mem_rf_wdata
    } = mem_to_rf_bus;
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;



    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;//基址
    wire [15:0] offset;//偏移
    wire [2:0] sel;//选择信号

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;
    wire [31:0] ndata1, ndata2;

//  数据相关
    assign ndata1 = ((ex_rf_we && rs == ex_rf_waddr) ? ex_rf_wdata : 32'b0) | 
                   ((mem_rf_we && rs == mem_rf_waddr) ? mem_rf_wdata : 32'b0) |
                   ((wb_rf_we && rs == wb_rf_waddr) ? wb_rf_wdata : 32'b0) |
                   (((ex_rf_we && rs == ex_rf_waddr) || (mem_rf_we && rs == mem_rf_waddr) || (wb_rf_we && rs == wb_rf_waddr)) ? 32'b0 : rdata1);

    assign ndata2 = ((ex_rf_we && rt == ex_rf_waddr) ? ex_rf_wdata : 32'b0) | 
                   ((mem_rf_we && rt == mem_rf_waddr) ? mem_rf_wdata : 32'b0) |
                   ((wb_rf_we && rt == wb_rf_waddr) ? wb_rf_wdata : 32'b0) |
                   (((ex_rf_we && rt == ex_rf_waddr) || (mem_rf_we && rt == mem_rf_waddr) || (wb_rf_we && rt == wb_rf_waddr)) ? 32'b0 : rdata2);

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );

    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

// 算术运算指令
    wire inst_addu; // 将寄存器 rs 的值与寄存器 rt 的值相加，结果写入 rd 寄存器中。
    wire inst_addiu;// 将寄存器 rs 的值与有符号扩展 至 32 位的立即数 imm 相加，结果写入 rt 寄存器中。
    wire inst_add;  // 将寄存器 rs 的值与寄存器 rt 的值相加，结果写入寄存器 rd 中。
                    // 如果产生溢出，则触发整型溢出例外（IntegerOverflow）。
    wire inst_addi; // 将寄存器 rs 的值与有符号扩展至 32 位的立即数 imm 相加，结果写入 rt 寄存器中。
                    // 如果产生溢出，则触发整型溢出例外（IntegerOverflow）。


    wire inst_sub;  //将寄存器 rs 的值与寄存器 rt 的值相减，结果写入 rd 寄存器中。
                    // 如果产生溢出，则触发整型溢出例外（IntegerOverflow）。
    wire inst_subu; // 将寄存器 rs 的值与寄存器 rt 的值相减，结果写入 rd 寄存器中。


    wire inst_slt;  //将寄存器 rs 的值与寄存器 rt 中的值进行有符号数比较，
                    // 如果寄存器 rs 中的值小，则寄存器 rd 置 1；否则寄存器 rd 置 0。
    wire inst_slti; //将寄存器 rs 的值与有符号扩展至 32 位的立即数 imm 进行有符号数比较，
                    // 如果寄存器 rs 中的值小，则寄存器 rt 置 1；否则寄存器 rt 置 0。
    wire inst_sltu; // 将寄存器 rs 的值与寄存器 rt 中的值进行无符号数比较，
                     // 如果寄存器 rs 中的值小，则寄存器 rd 置 1；否则寄存器 rd 置 0。
    wire inst_sltiu;// 将寄存器 rs 的值与有符号扩展至 32 位的立即数 imm 进行无符号数比较，
                    // 如果寄存器 rs 中的值小，则寄存器 rt 置 1；否则寄存器 rt 置 0。

// 逻辑运算指令
    wire inst_ori;  // 寄存器 rs 中的值与 0 扩展至 32 位的立即数 imm 按位逻辑或，结果写入寄存器 rt 中。
    wire inst_lui;  // 将 16 位立即数 imm 写入寄存器 rt 的高 16 位，寄存器 rt 的低 16 位置 0。
    wire inst_or;   // 寄存器 rs 中的值与寄存器 rt 中的值按位逻辑或，结果写入寄存器 rd 中。
    wire inst_xor;  // 寄存器 rs 中的值与寄存器 rt 中的值按位逻辑异或，结果写入寄存器 rd 中。
    wire inst_xori; // 寄存器 rs 中的值与 0 扩展至 32 位的立即数 imm 按位逻辑或，结果写入寄存器 rt 中。
    wire inst_and;  // 寄存器 rs 中的值与寄存器 rt 中的值按位逻辑与，结果写入寄存器 rd 中。
    wire inst_nor;  // 寄存器 rs 中的值与寄存器 rt 中的值按位逻辑或，结果写入寄存器 rd 中。
    wire inst_andi; // 寄存器 rs 中的值与 0 扩展至 32 位的立即数 imm 按位逻辑与，结果写入寄存器 rt 中。

// 移位指令
    wire inst_sll;  // 由立即数 sa 指定移位量，对寄存器 rt 的值进行逻辑左移，结果写入寄存器 rd 中。
    wire inst_sla;  // 由立即数 sa 指定移位量，对寄存器 rt 的值进行算术左移，结果写入寄存器 rd 中。
    wire inst_srl;  // 由立即数 sa 指定移位量，对寄存器 rt 的值进行逻辑右移，结果写入寄存器 rd 中。
    wire inst_sra;  // 由立即数 sa 指定移位量，对寄存器 rt 的值进行算术右移，结果写入寄存器 rd 中。
    wire inst_sllv; // 寄存器 rs 中的值的低 5 位指定移位量，对寄存器 rt 的值进行逻辑左移，结果写入寄存器 rd 中。
    wire inst_srav; // 寄存器 rs 中的值的低 5 位指定移位量，对寄存器 rt 的值进行算术右移，结果写入寄存器 rd 中。
    wire inst_srlv; // 寄存器 rs 中的值的低 5 位指定移位量，对寄存器 rt 的值进行逻辑右移，结果写入寄存器 rd 中。

// 分支跳转指令
    wire inst_beq;  // 如果寄存器 rs 的值等于寄存器 rt 的值则转移，否则顺序执行。
                    // 转移目标由立即数 offset 左移 2 位并进行有符号扩展的值加上该分支指令对应的延迟槽指令的 PC 计算得到。
    wire inst_bne;  // 如果寄存器 rs 的值不等于寄存器 rt 的值则转移，否则顺序执行。
                    // 转移目标由立即数 offset 左移 2位并进行有符号扩展的值
                    // 加上该分支指令对应的延迟槽指令的 PC 计算得到。
    wire inst_jr;   // 无条件跳转。跳转目标为寄存器 rs 中的值。
    wire inst_jal;  // 无条件跳转。跳转目标由该分支指令对应的延迟槽指令的 PC 的最高 4 位与立即数 instr_index 左移2 位后的值拼接得到。
                    // 同时将该分支对应延迟槽指令之后的指令的 PC 值保存至第 31 号通用寄存器中。

    wire inst_jalr; // 无条件跳转。跳转目标为寄存器 rs 中的值。
                    // 同时将该分支对应延迟槽指令之后的指令的 PC 值保存至第 31 号通用寄存器中。

//访存指令
    wire inst_lw;   // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址，
                    // 如果地址不是 4 的整数倍则触发地址错例外，
                    // 否则据此虚地址从存储器中读取连续 4 个字节的值，写入到 rt 寄存器中。
    wire inst_sw;   // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址，
                    // 如果地址不是 4 的整数倍则触发地址错例外，
                    // 否则据此虚地址将 rt 寄存器存入存储器中。

    wire inst_lb;   // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址,
                    // 据此虚地址从存储器中读取 1 个字节的值并进行符号扩展，写入到 rt 寄存器中。
    wire inst_lbu;  // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址，
                    // 据此虚地址从存储器中读取 1 个字节的值并进行 0 扩展，写入到 rt 寄存器中。
    wire inst_lh;   // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址，如果地址不是 2 的整数倍
                    // 则触发地址错例外，否则据此虚地址从存储器中读取连续 2 个字节的值并进行符号扩展，写入到rt 寄存器中。

    wire inst_lhu;  // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址，如果地址不是 2 的整数倍则触发地址错例外，
                    // 否则据此虚地址从存储器中读取连续 2 个字节的值并进行 0 扩展，写入到 rt寄存器中。
    wire inst_sb;   // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址，据此虚地址将 rt 寄存器的最低字节存入存储器中。
    wire inst_sh;   // 将 base 寄存器的值加上符号扩展后的立即数 offset 得到访存的虚地址，如果地址不是 2 的整数倍则触发地址错例外，
                    // 否则据此虚地址将 rt 寄存器的低半字存入存储器中。

    // 数据移动指令




    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    // 6-64译码器
    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    // 6-64译码器
    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );

    // 5-32译码器
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    // 5-32译码器
    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );


     decoder_5_32 u2_decoder_5_32(
    	.in  (rd  ),
        .out (rd_d )
    );

     decoder_5_32 u3_decoder_5_32(
    	.in  (sa  ),
        .out (sa_d )
    );



    // """算术运算指令"""
    
    // 加（可产生溢出例外）
    assign inst_add     = op_d[6'b00_0000] & func_d[6'b10_0000];    
    // 加立即数（可产生溢出例外）
    assign inst_addi    = op_d[6'b00_1000];    
    // 加（不产生溢出例外）
     assign inst_addu    = op_d[6'b00_0000] & func_d[6'b10_0001];   
    // 加立即数（不产生溢出例外）
    assign inst_addiu   = op_d[6'b00_1001];    
    // 减（可产生溢出例外）
    assign inst_sub     = op_d[6'b00_0000] & func_d[6'b10_0010];    
    // 减（不产生溢出例外）
    assign inst_subu    = op_d[6'b00_0000] & func_d[6'b10_0011];    
    // 有符号小于置 1
    assign inst_slt     = op_d[6'b00_0000] & func_d[6'b10_1010];    
    // 有符号小于立即数设置 1
    assign inst_slti    = op_d[6'b00_1010];    
    // 无符号小于设置 1
    assign inst_sltu    = op_d[6'b00_0000] & func_d[6'b10_1011];    
    // 无符号小于设置 1
    assign inst_sltiu   = op_d[6'b00_1011];    
    // 有符号字除
    // 无符号字除
    // 有符号字乘
    // 无符号字乘

    // """逻辑运算指令"""

    // 位与
    assign inst_and     = op_d[6'b00_0000] & func_d[6'b10_0100]; 
    // 立即数位与
    assign inst_andi    = op_d[6'b00_1100]; 
    // 寄存器高半部分置立即数
    assign inst_lui     = op_d[6'b00_1111];    
    // 位或非
    assign inst_nor     = op_d[6'b00_0000] & func_d[6'b10_0111]; 
    // 位或
    assign inst_or      = op_d[6'b00_0000] & func_d[6'b10_0101];   
    // 立即数位或
    assign inst_ori     = op_d[6'b00_1101];    
    // 位异或
    assign inst_xor     = op_d[6'b00_0000] & func_d[6'b10_0110];    
    // 立即数位异或
    assign inst_xori    = op_d[6'b00_1110];
   
    
    // """移位指令"""

    // 立即数逻辑左移
    assign inst_sll     = op_d[6'b00_0000] & func_d[6'b00_0000];    
    // 变量逻辑左移
    assign inst_sllv     = op_d[6'b00_0000] & func_d[6'b00_0100];
    // 立即数算术右移
    assign inst_sra     = op_d[6'b00_0000] & func_d[6'b00_0011];
    // 变量算术右移
    assign inst_srav     = op_d[6'b00_0000] & func_d[6'b00_0111];
    // 立即数逻辑右移
    assign inst_srl     = op_d[6'b00_0000] & func_d[6'b00_0010];
    // 变量逻辑右移
    assign inst_srlv     = op_d[6'b00_0000] & func_d[6'b00_0110];


    // """分支跳转指令"""

    // 相等转移
    assign inst_beq     = op_d[6'b00_0100];
    // 不等转移
    assign inst_bne     = op_d[6'b00_0101];  
    // 大于等于 0 转移
// assign inst_bnez     = op_d[6'b00_0001] & rt_d[6'b0_0001]; 
    // 大于 0 转移
// assign inst_bgtz     = op_d[6'b00_0111] & rt_d[6'b0_0000]; 
    // 小于等于 0 转移
// assign inst_blez     = op_d[6'b00_0110] & rt_d[6'b0_0000]; 
    // 小于 0 转移
// assign inst_bltz     = op_d[6'b00_0001] & rt_d[6'b0_0000];
    // 小于 0 调用子程序并保存返回地址
// assign inst_bgtzal     = op_d[6'b00_0001] & rt_d[6'b1_0000];
    // 大于等于 0 调用子程序并保存返回地址
// assign inst_bgezal     = op_d[6'b00_0001] & rt_d[6'b1_0001];
    // 无条件直接跳转
// assign inst_j     = op_d[6'b00_0010];
    // 无条件直接跳转至子程序并保存返回地址
    assign inst_jal     = op_d[6'b00_0011];
    // 无条件寄存器跳转
    assign inst_jr      = op_d[6'b00_0000] & func_d[6'b00_1000];
    // 无条件寄存器跳转至子程序并保存返回地址下
    assign inst_jalr      = op_d[6'b00_0000]  & rt_d[6'b0_0000] & func_d[6'b00_1001];


    // """数据移动指令"""
    // HI 寄存器至通用寄存器
    // LO 寄存器至通用寄存器
    // 通用寄存器至 HI 寄存器
    // 通用寄存器至 LO 寄存器

    // """访存指令"""   

    // 取字节有符号扩展
    assign inst_lb      = op_d[6'b10_0000];
    // 取字节无符号扩展
    assign inst_lbu     = op_d[6'b10_0100];
    // 取半字有符号扩展
    assign inst_lh      = op_d[6'b10_0001];
    // 取半字无符号扩展
    assign inst_lhu     = op_d[6'b10_0101];
    // 取字
    assign inst_lw      = op_d[6'b10_0011];
    // 存字节
    assign inst_sb      = op_d[6'b10_1000];
    // 存半字
    assign inst_sh      = op_d[6'b10_1001];
    // 存字
    assign inst_sw      = op_d[6'b10_1011];


    // rs to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_jr | inst_addu | inst_or | inst_xor | inst_lw | inst_sw;

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal | inst_jalr;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl;

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sra | inst_srl ;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw | inst_sw | inst_slti| inst_sltiu | inst_addi;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal | inst_jalr;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori;



    assign op_add = inst_add | inst_addi | inst_addiu | inst_jal | inst_addu | inst_lw | inst_sw| inst_add | inst_addi;
    assign op_sub = inst_subu | inst_sub;
    assign op_slt = inst_slt | inst_slti;
    assign op_sltu = inst_sltu | inst_sltiu;
    assign op_and = inst_and | inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor | inst_xori;
    assign op_sll = inst_sll | inst_sllv;
    assign op_srl = inst_srl | inst_srlv;
    assign op_sra = inst_sra | inst_srav;
    assign op_lui = inst_lui;

    // alu在 /lib/alu.v中定义，线序正确
    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = inst_sw|inst_lw;


    // write enable
    assign data_ram_wen = inst_sw;



    // regfile store enable
    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_subu | inst_jal | inst_addu| inst_sll | 
                    inst_or | inst_xor | inst_lw | 
                    inst_add | inst_addi | inst_sub | inst_slt | inst_slti | inst_sltu | inst_sltiu| inst_jalr|
                    inst_jr| inst_and | inst_andi | inst_nor | inst_sra | inst_srl | inst_srlv | inst_srav;



    // store in [rd]
    assign sel_rf_dst[0] =  inst_sub |inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_add |  
                            inst_slt | inst_sltu |
                            inst_and | inst_nor | inst_sra | inst_srl | inst_srlv | inst_srav |inst_sllv ;
    
    
    // store in [rt] 
    assign sel_rf_dst[1] =  inst_ori | inst_lui | inst_addiu | inst_lw | inst_addi | inst_slti | inst_sltiu |
                            inst_andi | inst_xori     ;
    
    
    // store in [31]
    assign sel_rf_dst[2] = inst_jal | inst_jalr;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = inst_lw; 

    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        ndata1,         // 63:32
        ndata2          // 31:0
    };



    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;

    assign rs_eq_rt = (ndata1 == ndata2);

    assign br_e = inst_beq & rs_eq_rt | inst_jr | inst_jal | inst_bne & ~rs_eq_rt;
    assign br_addr = (inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 32'b0) |
                     (inst_jr ? ndata1 : 32'b0) |
                     (inst_jal ? {pc_plus_4[31:28],instr_index,2'b0} : 32'b0) |
                     (inst_bne ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 32'b0);

    assign id_load_bus = {
        inst_lb,
        inst_lbu,
        inst_lh,
        inst_lhu,
        inst_lw
    };

    assign id_save_bus = {
        inst_sb,
        inst_sh,
        inst_sw
    };

    assign br_bus = {
        br_e,
        br_addr
    };
    
    assign stallreq_for_bru = ex_id & 
    ((ex_rf_we == 1'b1 && ex_rf_waddr == rs) ? `Stop : `NoStop | (ex_rf_we == 1'b1 && ex_rf_waddr == rt) ? `Stop : `NoStop)
    
     ; //inst_beq | inst_bne | inst_jr | inst_jal;



endmodule