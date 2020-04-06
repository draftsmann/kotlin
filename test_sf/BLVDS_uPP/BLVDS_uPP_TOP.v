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
    wire          wACLR,wACLR_A,wACLR_B,wRD_REQ,wWR_FULL_A,wWR_FULL_B,wRD_EMPTY;
    wire          wSEND_OK,wSEL_CH_WR,wFULL_ERROR_STB,wHEAD_ERROR_STB,wEPILOG_ERROR_STB;
    wire          wEMPTY_A,wEMPTY_B,wRD_REQ_A,wRD_REQ_B,wWR_REQ_A,wWR_REQ_B,wSEL_CH_RD;
    wire          wGPIO5_DB,wFULL_ERROR,wHEAD_ERROR,wEPILOG_ERROR;
    wire          wWRFULL,wWR_REQ,wRST_BLVDS_RECEIVER,wRST_ERR_SOLV,wRST_BUTTON;
    wire   [8:0]  wRDUSEDW,wRDUSEDW_A,wRDUSEDW_B;
    wire   [15:0] wFIFO_OUT_A,wFIFO_OUT_B;

// Коммутация каналов запроса на запись в FIFO
    assign wWR_REQ_A = (wSEL_CH_WR)? wWR_REQ:1'b0;
    assign wWR_REQ_B = (!wSEL_CH_WR)? wWR_REQ:1'b0;
// Коммутация каналов сигнала асинхронного сброса FIFO
    assign wACLR_A = (wSEL_CH_WR)? wACLR:1'b0;
    assign wACLR_B = (!wSEL_CH_WR)? wACLR:1'b0;
// Коммутация каналов переполнения на запись FIFO
    assign wWRFULL = (wSEL_CH_WR)? wWR_FULL_A:wWR_FULL_B;
// Коммутация каналов запроса на чтение из FIFO
    assign wRD_REQ_A = (wSEL_CH_RD)? wRD_REQ:1'b0;
    assign wRD_REQ_B = (!wSEL_CH_RD)? wRD_REQ:1'b0;
// Коммутация каналов выходных данных FIFO
    assign wFIFO_OUT = (wSEL_CH_RD)? wFIFO_OUT_A:wFIFO_OUT_B;
// Коммутация каналов опустошения на чтение из FIFO
    assign wRD_EMPTY = (wSEL_CH_RD)? wEMPTY_A:wEMPTY_B;
// Коммутация каналов доступных для чтения данных FIFO
    assign wRDUSEDW = (wSEL_CH_RD)? wRDUSEDW_A:wRDUSEDW_B;
// Коммутация сигналов сброса модуля приема кадров ISSP и ERROR_SOLVER (соответственно)
    assign wRST_BLVDS_RECEIVER = wRST_BUTTON || wRST_ERR_SOLV;
// Модуль мегафункции FIFO для записи прнимаемых кадров (КАНАЛ А)
FIFO_16 FIFO_16_A (
    .aclr    ( wACLR_A     ),
    .data    ( wDATA_BLVDS ),
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
    .data    ( wDATA_BLVDS ),
    .rdclk   ( iC2_70MHZ   ),
    .rdreq   ( wRD_REQ_B   ),
    .wrclk   ( iC0_56MHZ   ),
    .wrreq   ( wWR_REQ_B   ),
    .q       ( wFIFO_OUT_B ),
    .rdempty ( wEMPTY_B    ),
    .wrfull  ( wWR_FULL_B  ),
    .rdusedw ( wRDUSEDW_B  )
);
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
