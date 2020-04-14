//==================================================================================================
//  Filename      : FIFO_SWITCH.v
//  Created On    : 2020-04-08 13:05:26
//  Last Modified : 2020-04-08 13:05:27
//  Revision      : 
//  Author        : Roman Kozhemyakin
//  Company       : AO Kotlin-Novator
//  Email         : kozhemyakin_rd@kotlin-novator.ru
//
//  Description   : 
//
//
//==================================================================================================
module FIFO_SWITCH
(
    input              iC0_56MHZ,iC2_70MHZ,
    input              iSEL_CH_WR,iWR_REQ,iACLR,
    input              iSEL_CH_RD,iRD_REQ,
    input   [15:0]     iDATA_BLVDS,

    output             oWRFULL,oRD_EMPTY,
    output  [8:0]      oRDUSEDW,
    output  [15:0]     oFIFO_OUT
);      
        
    wire          wACLR_A,wACLR_B,wWR_FULL_A,wWR_FULL_B;
    wire          wEMPTY_A,wEMPTY_B,wRD_REQ_A,wRD_REQ_B,wWR_REQ_A,wWR_REQ_B;
    wire   [8:0]  wRDUSEDW_A,wRDUSEDW_B;
    wire   [15:0] wFIFO_OUT_A,wFIFO_OUT_B;

// Коммутация каналов запроса на запись в FIFO
    assign wWR_REQ_A = (iSEL_CH_WR)?  iWR_REQ:1'b0;
    assign wWR_REQ_B = (!iSEL_CH_WR)? iWR_REQ:1'b0;
// Коммутация каналов сигнала асинхронного сброса FIFO
    assign wACLR_A   = (iSEL_CH_WR)?  iACLR:1'b0;
    assign wACLR_B   = (!iSEL_CH_WR)? iACLR:1'b0;
// Коммутация каналов переполнения на запись FIFO
    assign oWRFULL   = (iSEL_CH_WR)?  wWR_FULL_A:wWR_FULL_B;
// Коммутация каналов запроса на чтение из FIFO
    assign wRD_REQ_A = (iSEL_CH_RD)?  iRD_REQ:1'b0;
    assign wRD_REQ_B = (!iSEL_CH_RD)? iRD_REQ:1'b0;
// Коммутация каналов выходных данных FIFO
    assign oFIFO_OUT = (iSEL_CH_RD)?  wFIFO_OUT_A:wFIFO_OUT_B;
// Коммутация каналов опустошения на чтение из FIFO
    assign oRD_EMPTY = (iSEL_CH_RD)?  wEMPTY_A:wEMPTY_B;
// Коммутация каналов доступных для чтения данных FIFO
    assign oRDUSEDW  = (iSEL_CH_RD)?  wRDUSEDW_A:wRDUSEDW_B;
// Модуль мегафункции FIFO для записи прнимаемых кадров (КАНАЛ А)
FIFO_16 FIFO_16_A (
    .aclr    ( wACLR_A     ),
    .data    ( iDATA_BLVDS ),
    .rdclk   ( iC2_70MHZ   ),
    .rdreq   ( wRD_REQ_A   ),
    .wrclk   ( iC0_56MHZ   ),
    .wrreq   ( wWR_REQ_A   ),
    .q       ( wFIFO_OUT_A ),
    .rdempty ( wEMPTY_A    ),
    .wrfull  ( wWR_FULL_A  ),
    .rdusedw ( wRDUSEDW_A  )
);
// Модуль мегафункции FIFO для записи прнимаемых кадров (КАНАЛ B)
FIFO_16 FIFO_16_B (
    .aclr    ( wACLR_B     ),
    .data    ( iDATA_BLVDS ),
    .rdclk   ( iC2_70MHZ   ),
    .rdreq   ( wRD_REQ_B   ),
    .wrclk   ( iC0_56MHZ   ),
    .wrreq   ( wWR_REQ_B   ),
    .q       ( wFIFO_OUT_B ),
    .rdempty ( wEMPTY_B    ),
    .wrfull  ( wWR_FULL_B  ),
    .rdusedw ( wRDUSEDW_B  )
);

endmodule