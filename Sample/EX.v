`include "lib/defines.vh"
// 执行运算或计算地址（反正就是和ALU相关）
// 从ID/EX流水线寄存器中读取由寄存器1传过来的值和寄存器2传过来的值
// （或寄存器1传过来的值和符号扩展过后的立即数的值），
// 并用ALU将它们相加，结果值存入EX/MEM流水线寄存器。

// alu模块已经提供，基本通过给alu提供控制信号就可以完成逻辑和算术运算
// 对于需要访存的指令在此段发出访存请求

module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    // LW SW
    input wire [`LoadBus-1:0] id_load_bus,
    input wire [`SaveBus-1:0] id_save_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    // 
    output wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus,

    input wire [71:0] id_hi_lo_bus,
    output wire [65:0] ex_hi_lo_bus,

    output wire stallreq_for_ex,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire ex_id,
    output wire [3:0] data_ram_sel,
    output wire [`LoadBus-1:0] ex_load_bus
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    reg [`LoadBus-1:0] id_load_bus_r;
    reg [`SaveBus-1:0] id_save_bus_r;
    reg [71:0] id_hi_lo_bus_r;
    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            id_save_bus_r <= `SaveBus'b0;
            id_load_bus_r <= `LoadBus'b0;
            id_hi_lo_bus_r <= 71'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            id_save_bus_r <= `SaveBus'b0;
            id_load_bus_r <= `LoadBus'b0;
            id_hi_lo_bus_r <= 71'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
            id_save_bus_r <= id_save_bus;
            id_load_bus_r <= id_load_bus;
            id_hi_lo_bus_r <= id_hi_lo_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;
    wire [3:0] byte_sel;



    assign {
        ex_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw;
    wire inst_sb, inst_sh, inst_sw;

    wire inst_mfhi, inst_mflo, inst_mthi, inst_mtlo;
    wire inst_mult, inst_multu;
    wire inst_div, inst_divu;

    wire [31:0] hi;
    wire [31:0] lo;
    wire hi_we;
    wire lo_we;
    wire [31:0] hi_wdata;
    wire [31:0] lo_wdata;

    assign {
        inst_mfhi,
        inst_mflo,
        inst_mthi,
        inst_mtlo,
        inst_mult,
        inst_multu,
        inst_div,
        inst_divu,
        hi,
        lo
    }= id_hi_lo_bus_r;


    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op      ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    assign ex_result =  inst_mfhi ? hi :
                        inst_mflo ? lo :
                        alu_result;

    decoder_2_4 u_decoder_2_4(
        .in  (ex_result[1:0]),
        .out (byte_sel      )
    );

    assign ex_to_mem_bus = {

        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };

    assign ex_id = sel_rf_res;

    // forwording
    assign ex_to_rf_bus = {

        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };



    assign {
        inst_lb,
        inst_lbu,
        inst_lh,
        inst_lhu,
        inst_lw
    } = id_load_bus_r;

    assign {
        inst_sb,
        inst_sh,
        inst_sw
    } = id_save_bus_r;

    assign ex_load_bus = {
        inst_lb,
        inst_lbu,
        inst_lh,
        inst_lhu,
        inst_lw
    };

    // assign data_ram_sel = inst_lw | inst_sw ? 4'b1111 : 4'b0000;
    assign data_ram_sel =   inst_sb | inst_lb | inst_lbu ? byte_sel :
                            inst_sh | inst_lh | inst_lhu ? {{2{byte_sel[2]}},{2{byte_sel[0]}}} :
                            inst_sw | inst_lw ? 4'b1111 : 4'b0000;    
    assign data_sram_en = data_ram_en;
    // 根据写地址的最低两位addr[1:0]判断    
    assign data_sram_wen = {4{data_ram_wen}} & data_ram_sel;
    // 1号点后问题应该在写入数据上

    // assign data_sram_wen = inst_sw ? 4'b1111:
    //                     inst_sb & alu_result[1:0]==2'b00 ? 4'b0001:
    //                     inst_sb & alu_result[1:0]==2'b01 ? 4'b0010:
    //                     inst_sb & alu_result[1:0]==2'b10 ? 4'b0100:
    //                     inst_sb & alu_result[1:0]==2'b11 ? 4'b1000:
    //                     inst_sh & alu_result[1:0]==2'b00 ? 4'b0011:
    //                     inst_sh & alu_result[1:0]==2'b10 ? 4'b1100:
    //                     4'b0000;
    assign data_sram_addr = ex_result;
    assign data_sram_wdata  =   inst_sb ? {4{rf_rdata2[7:0]}}  :
                                inst_sh ? {2{rf_rdata2[15:0]}} : rf_rdata2;





    // assign ex_result =  inst_mfhi ? hi :
    //                     inst_mflo ? lo :
    //                     alu_result;

    assign ex_hi_lo_bus = {
        hi_we,
        lo_we,
        hi_wdata,
        lo_wdata
    };

    // MUL part
    wire [63:0] mul_result;
    wire mul_signed; // 有符号乘法标记

    assign mul_signed = inst_mult;

    // reg [31:0] mul_ina;
    // reg [31:0] mul_inb;


    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (mul_signed     ),
        .ina        (rf_rdata1        ), // 乘法源操作数1
        .inb        (rf_rdata2        ), // 乘法源操作数2
        .result     (mul_result     ) // 乘法结果 64bit
    );




    // DIV part
    wire [63:0] div_result;
    wire inst_div, inst_divu;
    wire div_ready_i;
    reg stallreq_for_div;
    assign stallreq_for_ex = stallreq_for_div;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;

    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );

    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // mul_result 和 div_result 可以直接使用
    
    assign hi_we = inst_mthi | inst_mult | inst_multu | inst_div | inst_divu;
    assign lo_we = inst_mtlo | inst_mult | inst_multu | inst_div | inst_divu;

    // 以乘法作为示例，如果两个整数相乘，那么乘法的结果低位保存在lo寄存器，高位保存在hi寄存器。
    assign hi_wdata = inst_mthi ? rf_rdata1 :
                      inst_mult | inst_multu ? mul_result[63:32] :
                      inst_div | inst_divu ? div_result[63:32] :
                      32'b0;

    assign lo_wdata = inst_mtlo ? rf_rdata1 :
                      inst_mult | inst_multu ? mul_result[31:0] :
                      inst_div | inst_divu ? div_result[31:0] :
                      32'b0;

    
endmodule