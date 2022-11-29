`timescale 1ns/100ps
module count_60(
    input wire rst,
    input wire clk,
    input wire en,
    output wire [7:0] count,
    output wire co
);

    wire[3:0] cout10, cout6;
    wire co10,co6,co1;

    count_10 u_count_10(
    	.rst   (rst   ),
        .clk   (clk   ),
        .en    (en    ),
        .count (cout10 ),
        .co    (co1    )
    );    

  and u_and_10(co10,en,co1);
    count_6 u_count_6(
    	.rst   (rst   ),
        .clk   (clk   ),
        .en    (co10    ),
        .count (cout6 ),
        .co    (co6    )
    );
    and u_and_6(co,co10,co6);

assign count ={cout6,cout10} ; //模60计数器的输出

endmodule

    module count_10(
    input wire rst,
    input wire clk,
    input wire en,
    output reg [3:0] count,
    output co
);
    always @ (posedge clk or negedge rst) begin
        if (rst) begin
            count <= 4'b0000;
            //co <= 1'b0;
        end
        else if (en) begin
            if (count == 4'd9) begin
                //co <= 1'b1;                
                count <= 4'b0;

            end
            else begin
                count <= count + 4'b1;
                //co <= 1'b0;
            end
        end
        else begin
            count <= count;
    end
    end
    assign co = count[0]&count[3];  //仅当计数达到9(4'b1001)时，进位为1
    endmodule

    module count_6(
    input wire rst,
    input wire clk,
    input wire en,
    output reg [3:0] count,
    output  co

);
    always @ (posedge clk) begin
        if (rst) begin
            count <= 4'b0000;
            //co <= 1'b0;
        end
        else if (en) begin
            if (count == 4'd5) begin
                //co <= 1'b1;                
                count <= 4'b0;
            end
            else begin
                count <= count + 4'b1;
                //co <= 1'b0;
            end
        end
        else begin
            count <= count;
        end
    end
    assign co = count[0]&count[2];  //仅当计数达到5(4'b0101)时，进位为1
    endmodule


    
