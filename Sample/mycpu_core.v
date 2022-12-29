`include "lib/defines.vh"
// CPU核心，定义流水线

module mycpu_core(
    input wire clk,
    input wire rst,
    input wire [5:0] int,

    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input wire [31:0] inst_sram_rdata,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input wire [31:0] data_sram_rdata,



    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;
    //forwording
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus;
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus;
    wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus;
    wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus;
    wire [`BR_WD-1:0] br_bus; 
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus;
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;
    wire [`LoadBus-1:0] id_load_bus;
    wire [`LoadBus-1:0] ex_load_bus;
    wire [3:0] data_ram_sel;
    wire [`SaveBus-1:0] id_save_bus;
    wire [`StallBus-1:0] stall;
    wire ex_id;

    wire [71:0] id_hi_lo_bus;
    wire [65:0] ex_hi_lo_bus;

    // stall
    wire stallreq_for_ex;
    wire stallreq_for_load;
    wire stallreq_for_bru;

    IF u_IF(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .br_bus          (br_bus          ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_en    (inst_sram_en    ),
        .inst_sram_wen   (inst_sram_wen   ),
        .inst_sram_addr  (inst_sram_addr  ),
        .inst_sram_wdata (inst_sram_wdata )
    );
    

    ID u_ID(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .stallreq        (stallreq        ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_rdata (inst_sram_rdata ),
        .wb_to_rf_bus    (wb_to_rf_bus    ),
        .ex_to_rf_bus    (ex_to_rf_bus    ),
        .mem_to_rf_bus   (mem_to_rf_bus   ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_id           (ex_id           ),
        .id_load_bus     (id_load_bus     ),
        .id_save_bus     (id_save_bus     ),
        .stallreq_for_bru(stallreq_for_bru),
        .br_bus          (br_bus          ),
        .id_hi_lo_bus    (id_hi_lo_bus    ),
        .ex_hi_lo_bus    (ex_hi_lo_bus    )
    );

    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        // .ex_to_id_bus    (ex_to_id_bus    ),
        .ex_id           (ex_id           ),
        .ex_to_rf_bus    (ex_to_rf_bus    ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .id_load_bus     (id_load_bus     ),
        .id_save_bus     (id_save_bus     ),
        .ex_load_bus     (ex_load_bus     ),
        .stallreq_for_ex (stallreq_for_ex ),
        .data_ram_sel    (data_ram_sel    ),
        .data_sram_en    (data_sram_en    ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata ),
        .id_hi_lo_bus    (id_hi_lo_bus    ),
        .ex_hi_lo_bus    (ex_hi_lo_bus    )
    );

    MEM u_MEM(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .ex_load_bus     (ex_load_bus     ),
        .data_sram_rdata (data_sram_rdata ),
        .data_ram_sel    (data_ram_sel    ),
        .stallreq_for_load(stallreq_for_load),
        .mem_to_wb_bus   (mem_to_wb_bus   ),
        .mem_to_rf_bus   (mem_to_rf_bus   )
    );
    
    
    WB u_WB(
    	.clk               (clk               ),
        .rst               (rst               ),
        .stall             (stall             ),
        .mem_to_wb_bus     (mem_to_wb_bus     ),
        .wb_to_rf_bus      (wb_to_rf_bus      ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    CTRL u_CTRL(
    	.rst   (rst   ),
        .stallreq_for_ex(stallreq_for_ex),
        .stallreq_for_load(stallreq_for_load),
        .stallreq_for_bru(stallreq_for_bru),
        .stall (stall )
    );
    
endmodule