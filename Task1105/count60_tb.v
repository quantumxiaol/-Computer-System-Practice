module count60_tb(

    );
    reg rst;
    reg clk;
    reg en;
    wire [7:0] count;
    wire co;

    initial begin
        rst = 0;
        clk = 0;
        en = 0;
        #2
        rst = 1;
        #2
        rst = 0;
        en = 1;
    end
    
    //时钟设计周期为2ns
    always #1 clk = ~clk;
    count_60 count60(rst,clk,en,count,co);    
endmodule
