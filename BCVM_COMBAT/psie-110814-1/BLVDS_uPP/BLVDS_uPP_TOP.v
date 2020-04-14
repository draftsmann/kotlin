//==================================================================================================
//  Filename      : BLVDS_uPP_TOP.v
//  Created On    : 2020-04-08 13:03:35
//  Last Modified : 2020-04-08 13:03:46
//  Revision      : 
//  Author        : Roman Kozhemyakin
//  Company       : AO Kotlin-Novator
//  Email         : kozhemyakin_rd@kotlin-novator.ru
//
//  Description   : 
//
//
//==================================================================================================
module BLVDS_uPP_TOP 
(
    input         iC0_56MHZ,iC2_70MHZ,iGPIO5,
    input [17:0]  iDATA_BLVDS,

    output [15:0] oFULL_ERR_CNT,
    output [15:0] oHEAD_ERR_CNT,
    output [15:0] oEPILOG_ERR_CNT,
    output [15:0] oDATA_UPP,
    output        oGPIO_0,
    output        oENA
);

    wire   [15:0] wFIFO_OUT;
    wire   [15:0] wDATA_BLVDS;
    wire          wACLR,wRD_REQ,wRD_EMPTY,wSEL_CH_RD;
    wire          wSEND_OK,wSEL_CH_WR,wFULL_ERROR_STB,wHEAD_ERROR_STB,wEPILOG_ERROR_STB;
    wire          wGPIO5_DB,wFULL_ERROR,wHEAD_ERROR,wEPILOG_ERROR;
    wire          wWRFULL,wWR_REQ,wRST_BLVDS_RECEIVER,wRST_ERR_SOLV,wRST_BUTTON;
    wire   [8:0]  wRDUSEDW;

// Коммутация сигналов сброса модуля приема кадров ISSP и ERROR_SOLVER (соответственно)
    assign wRST_BLVDS_RECEIVER = wRST_BUTTON || wRST_ERR_SOLV;

// Модуль коммутации каналов FIFO
FIFO_SWITCH FIFO_SWITCH_inst (
    .iC0_56MHZ   ( iC0_56MHZ   ) ,
    .iC2_70MHZ   ( iC2_70MHZ   ) ,
    .iSEL_CH_WR  ( wSEL_CH_WR  ) ,
    .iWR_REQ     ( wWR_REQ     ) ,
    .iACLR       ( wACLR       ) ,
    .iSEL_CH_RD  ( wSEL_CH_RD  ) ,
    .iRD_REQ     ( wRD_REQ     ) ,
    .iDATA_BLVDS ( wDATA_BLVDS ) ,
    .oWRFULL     ( wWRFULL     ) ,
    .oRD_EMPTY   ( wRD_EMPTY   ) ,
    .oRDUSEDW    ( wRDUSEDW    ) ,
    .oFIFO_OUT   ( wFIFO_OUT   )
);
// Модуль мегафункции In-System Sources and Probes (сброс модуля BLVDS_RECEIVER)
rst_button rst_button_inst (
    .source(wRST_BUTTON)
);
// Модуль приемника кадров по BLVDS
BLVDS_RECEIVER BLVDS_RECEIVER_inst (
    .iCLK           ( iC0_56MHZ           ) ,
    .iRST           ( wRST_BLVDS_RECEIVER ) ,
    .iDATA_BLVDS    ( iDATA_BLVDS         ) ,
    .oSEND_OK       ( wSEND_OK            ) ,
    .oWR_REQ        ( wWR_REQ             ) ,
    .oFULL_ERROR    ( wFULL_ERROR         ) ,
    .oHEAD_ERROR    ( wHEAD_ERROR         ) ,
    .oEPILOG_ERROR  ( wEPILOG_ERROR       ) ,
    .iWR_FULL       ( wWRFULL             ) ,
    .oDATA_BLVDS    ( wDATA_BLVDS         ) ,
    .oSEL_CHANNEL   ( wSEL_CH_WR          ), 
    .oACLR_FIFO     ( wACLR               )  
);
defparam BLVDS_RECEIVER_inst.COLLISION_DELAY = 8'd100; // Величина задержки в случае выявления ошибки приема
defparam BLVDS_RECEIVER_inst.FRAME_DELAY     = 8'd100; // Величина задержки перед приемом нового кадра
// Модуль формирования строба из сигнала ошибки переполнения
Strob_cutter Strob_cutter_FULL (
    .iclk        ( iC0_56MHZ       ) ,
    .ibutton     ( wFULL_ERROR     ) ,
    .o_start_str ( wFULL_ERROR_STB )  
);
// Модуль формирования строба из сигнала ошибки принятия заголовка
Strob_cutter Strob_cutter_HEAD (
    .iclk        ( iC0_56MHZ       ) ,
    .ibutton     ( wHEAD_ERROR     ) ,
    .o_start_str ( wHEAD_ERROR_STB )  
);
// Модуль формирования строба из сигнала ошибки принятия эпилога
Strob_cutter Strob_cutter_EPILOG (
    .iclk        ( iC0_56MHZ         ) ,
    .ibutton     ( wEPILOG_ERROR     ) ,
    .o_start_str ( wEPILOG_ERROR_STB )  
);
// Модуль сбора статистики об ошибках
ERROR_SOLVER ERROR_SOLVER_inst (
    .iCLK                ( iC0_56MHZ           ) , 
    .iFULL_ERROR         ( wFULL_ERROR_STB     ) , 
    .iHEAD_ERROR         ( wHEAD_ERROR_STB     ) , 
    .iEPILOG_ERROR       ( wEPILOG_ERROR_STB   ) , 
    .oRST_BLVDS_RECEIVER ( wRST_ERR_SOLV       ) ,
    .oFULL_ERR_CNT       ( oFULL_ERR_CNT       ) , 
    .oHEAD_ERR_CNT       ( oHEAD_ERR_CNT       ) , 
    .oEPILOG_ERR_CNT     ( oEPILOG_ERR_CNT     )
);
defparam ERROR_SOLVER_inst.ERR_NUM = 16'd5; // Колличество ошибок при котором инициализируется сброс
// Модуль устранения дребезга (наводок)
button_debouncer button_debouncer_inst (
    .iCLK       ( iC2_70MHZ ) ,
    .iRST       (           ) ,
    .iSW        ( iGPIO5    ) ,
    .oSW_STATE  ( wGPIO5_DB ) ,
    .oSW_DOWN   (           ) ,
    .oSW_UP     (           )  
);
defparam button_debouncer_inst.CNT_WIDTH = 7; // Разрядность счетчика проверяющего стабильность лог. уровня
// Модуль обработки прерываний и передачи по uPP
GPIO_SOLVER GPIO_SOLVER_inst (
    .iCLK           ( iC2_70MHZ  ) ,
    .iRST           (            ) ,
    .iSTART         ( wSEND_OK   ) ,
    .iGPIO5         ( wGPIO5_DB  ) ,
    .iEMPTY         ( wRD_EMPTY  ) ,
    .iSEL_CHANNEL   ( wSEL_CH_WR ) ,
    .iUSEDW         ( wRDUSEDW   ) ,
    .iFIFO_OUT      ( wFIFO_OUT  ) ,
    .oDATA_UPP      ( oDATA_UPP  ) ,
    .oRD_REQ        ( wRD_REQ    ) ,
    .oGPIO_0        ( oGPIO_0    ) ,
    .oSEL_CHANNEL   ( wSEL_CH_RD ) ,
    .oENA           ( oENA       )  
);
defparam GPIO_SOLVER_inst.USEDW_VALUE    = 9'd256; // Глубина заполнения FIFO при которой начинается запись
defparam GPIO_SOLVER_inst.CHECK_GPIO5    = 9'd100; // Период проверки сброса GPIO_5 для формирования GPIO_0
defparam GPIO_SOLVER_inst.BETWEEN_FRAMES = 9'd100; // Задержка между вычитываниями кадров

endmodule
