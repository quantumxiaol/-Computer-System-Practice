`include "lib/defines.vh"
// 访问内存操作
// 可能从EX/MEM流水线寄存器中得到地址读取数据寄存器，并将数据存入MEM/WB流水线寄存器。

// 接收并处理访存的结果，并选择写回结果
// 对于需要访存的指令在此段接收访存结果

module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    input wire [31:0] data_sram_rdata,

    input wire [3:0] data_ram_sel,

    input wire [`LoadBus-1:0] ex_load_bus,

    output wire stallreq_for_load,

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,

    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus
);
    reg [`LoadBus-1:0] ex_load_bus_r;
    reg [3:0] data_ram_sel_r;

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            data_ram_sel_r <= 3'b0;            
            ex_load_bus_r <= `LoadBus'b0;

        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            data_ram_sel_r <= 3'b0;            
            ex_load_bus_r <= `LoadBus'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
            data_ram_sel_r <= data_ram_sel;            
            ex_load_bus_r <= ex_load_bus;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;

    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw;

    wire [7:0] b_data;
    wire [15:0] h_data;
    wire [31:0] w_data;


    assign {
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;

    assign {
        inst_lb,//4
        inst_lbu,//3
        inst_lh,//2
        inst_lhu,//1
        inst_lw//0
    } = ex_load_bus_r;

// sb指令一次只写入一个字节，所以可能是4'b0001 4'b0010 4'b0100 4'b1000这四种情况，
// 具体选择那种，根据写地址的最低两位addr[1:0]判断。
// 00对应最低位字节(data_sram_wen应为4'b0001)；
// 11对应最高位字节(data_sram_wen应为4'b1000)。
// sh指令类似于sb指令，但其只有两种情况，地址最低两位为00对应低位两个字节(data_sram_wen应为4'b0011)；
// 地址最低两位为10时对应高位两个字节(data_sram_wen应为4'b1100)。

// load类指令与store类指令略有不同，
// 由于这个存储器只配置了片选(4byte)使能和字节写使能，
// 所以读取的时候一律是先读回CPU(此时不区分是哪个load指令)，
// 在MEM段再进行更细分的操作。
// load类指令的字节选择方法和store类相同

    assign b_data = data_ram_sel_r[3] ? data_sram_rdata[31:24] : 
                    data_ram_sel_r[2] ? data_sram_rdata[23:16] :
                    data_ram_sel_r[1] ? data_sram_rdata[15: 8] : 
                    data_ram_sel_r[0] ? data_sram_rdata[ 7: 0] : 8'b0;
    assign h_data = data_ram_sel_r[2] ? data_sram_rdata[31:16] :
                    data_ram_sel_r[0] ? data_sram_rdata[15: 0] : 16'b0;
    assign w_data = data_sram_rdata;

    assign mem_result = inst_lb     ? {{24{b_data[7]}},b_data} :
                        inst_lbu    ? {{24{1'b0}},b_data} :
                        inst_lh     ? {{16{h_data[15]}},h_data} :
                        inst_lhu    ? {{16{1'b0}},h_data} :
                        inst_lw     ? w_data : 32'b0; 

    assign rf_wdata =   sel_rf_res & data_ram_en ? mem_result :
                        ex_result;

    assign mem_to_wb_bus = {

        mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };

    assign mem_to_rf_bus = {
        // mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };


endmodule