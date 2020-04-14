//==================================================================================================
//  Filename      : ERROR_SOLVER.v
//  Created On    : 2020-04-08 13:06:02
//  Last Modified : 2020-04-08 13:06:02
//  Revision      : 
//  Author        : Roman Kozhemyakin
//  Company       : AO Kotlin-Novator
//  Email         : kozhemyakin_rd@kotlin-novator.ru
//
//  Description   : 
//
//
//==================================================================================================
module ERROR_SOLVER #(
    ERR_NUM = 16'd5 // Колличество ошибок при котором инициализируется сброс
)
(
    input              iCLK,
    input              iFULL_ERROR,iHEAD_ERROR,iEPILOG_ERROR,

    output reg         oRST_BLVDS_RECEIVER,
    output      [15:0] oFULL_ERR_CNT,oHEAD_ERR_CNT,oEPILOG_ERR_CNT
);      
        
    reg                rFULL_ERROR,rHEAD_ERROR,rEPILOG_ERROR,rSCLR_CNT;
    wire        [15:0] wERR_STAT;
// Модуль мегафункции счетчика ошибок преполнения
ERR_CNT ERR_CNT_FULL (
    .clock  ( iCLK          ),
    .sclr   ( rSCLR_CNT     ),
    .cnt_en ( rFULL_ERROR   ),
    .q      ( oFULL_ERR_CNT )
);
// Модуль мегафункции счетчика ошибок заголовков
ERR_CNT ERR_CNT_HEAD (
    .clock  ( iCLK          ),
    .sclr   ( rSCLR_CNT     ),
    .cnt_en ( rHEAD_ERROR   ),
    .q      ( oHEAD_ERR_CNT )
);
// Модуль мегафункции счетчика ошибок эпилогов
ERR_CNT ERR_CNT_EPILOG (
    .clock  ( iCLK            ),
    .sclr   ( rSCLR_CNT       ),
    .cnt_en ( rEPILOG_ERROR   ),
    .q      ( oEPILOG_ERR_CNT )
);
// Защелкивание входных сигналов об ошибках в регистры
always @(posedge iCLK) begin
    rEPILOG_ERROR <= iEPILOG_ERROR;
    rFULL_ERROR   <= iFULL_ERROR;
    rHEAD_ERROR   <= iHEAD_ERROR;
end
// Анализ кол-ва ошибок и формирование сигнала сброса модуля BLVDS_RECEIVER
always @(posedge iCLK) begin
    if ((oFULL_ERR_CNT > ERR_NUM) || (oHEAD_ERR_CNT > ERR_NUM) || (oEPILOG_ERR_CNT > ERR_NUM)) begin// if (wERR_STAT > 16'd5) begin
        oRST_BLVDS_RECEIVER <= 1; // Инициализация синхронного сброса модуля приема кадров по BLVDS
        rSCLR_CNT           <= 1;
    end
    else begin
        oRST_BLVDS_RECEIVER <= 0;
        rSCLR_CNT           <= 0;
    end
end

endmodule