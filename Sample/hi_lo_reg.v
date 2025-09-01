`include "lib/defines.vh"
// hi和lo属于协处理器，不在通用寄存器的范围内。
// 这两个寄存器主要是在用来处理乘法和除法。
// 以乘法作为示例，如果两个整数相乘，那么乘法的结果低位保存在lo寄存器，高位保存在hi寄存器。
// 当然，这两个寄存器也可以独立进行读取和写入。读的时候，使用mfhi、mflo；写入的时候，用mthi、mtlo。
// 和通用寄存器不同，mfhi、mflo是在执行阶段才开始从hi、lo寄存器获取数值的。写入则和通用寄存器一样，也是在写回的时候完成的。

module hi_lo_reg(
    input wire clk,
    // input wire rst,
    input wire [`StallBus-1:0] stall,

    input wire hi_we,
    input wire lo_we,

    input wire [31:0] hi_wdata,
    input wire [31:0] lo_wdata,

    output wire [31:0] hi_rdata,
    output wire [31:0] lo_rdata
);

    reg [31:0] reg_hi;
    reg [31:0] reg_lo;



    always @ (posedge clk) begin
        if (hi_we & lo_we) begin
            reg_hi <= hi_wdata;
            reg_lo <= lo_wdata;
        end
        if (~hi_we & lo_we) begin
            reg_lo <= lo_wdata;
        end
        if (hi_we & ~lo_we) begin
            reg_hi <= hi_wdata;
        end
    end

    assign hi_rdata = reg_hi;
    assign lo_rdata = reg_lo;

    // always @ (posedge clk) begin
    //     if (rst) begin
    //         reg_hi <= 32'b0;
    //         reg_lo <= 32'b0;
    //     end
    //     else if (wb_lo_we) begin
    //         reg_hi <= wb_hi_in;
    //         reg_lo <= wb_lo_in;
    //     end
    // end



endmodule