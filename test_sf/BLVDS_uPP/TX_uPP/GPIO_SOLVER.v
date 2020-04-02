module GPIO_SOLVER
#(
    USEDW_VALUE    = 9'd256, // Глубина заполнения FIFO при которой начинается запись
    CHECK_GPIO5    = 9'd100, // Период проверки сброса GPIO_5 для формирования GPIO_0
    BETWEEN_FRAMES = 9'd100  // Задержка между вычитываниями кадров
)
(
    input               iCLK,iRST,iSTART,
    input               iGPIO5,iEMPTY,iSEL_CHANNEL,
    input       [8:0]   iUSEDW,
    input       [15:0]  iFIFO_OUT,

    output  reg [15:0]  oDATA_UPP,
    output  reg         oRD_REQ,oACLR_FIFO,oGPIO_0,oSEL_CHANNEL,oENA
);

    reg                 rSTART_RST,rGPIO_5,rFULL,rSTART,rFLAG_CONT;
    reg         [8:0]   rWORD_CNT,rLATENCY_CNT,rLATENCY,rEND_CNT,rGPIO0_CNT,rUSEDW;

// Declare the state register to be "safe" to implement
// a safe state machine that can recover gracefully from
// an illegal state (by returning to the reset state).
    (* syn_encoding = "safe" *) reg [2:0] state;
// Declare states
localparam GPIO_5       = 0, // Состояние ожидания прерывания (готовности) GPIO_5 от DSP
           USEDW        = 1, // Состояние проверки заполненности (USEDW) FIFO для чтения (или сигнала окончания приема кадра)
           FIFO_LATENCY = 2, // Состояние формирования задержки перед чтением (в параметрах FIFO)
           DATA_READ    = 3, // Состояние чтения пакетов из FIFO при заполненности FIFO до порога (USEDW)
           GPIO_0       = 4, // Состояние формирования стимулирующих импульсов и GPIO_0
           END_LATENCY  = 5; // Состояние формирования задержки между чтениями кадров
// Начальная инициализация
initial begin
    state = GPIO_5; // !!!
end
// Модуль встроенной функции RS-flip-flop
SRFF SRFF_iSTART (
    .s    ( iSTART     ), 
    .r    ( rSTART_RST ), 
    .clk  ( iCLK       ), 
    .clrn (            ), 
    .prn  (            ), 
    .q    ( rSTART     )
);
// Защелкивание входного значения доступных для чтения данных в регистр
always @(posedge iCLK) begin
    rUSEDW <= iUSEDW;
end
// Main
always @(posedge iCLK or posedge iRST) begin
    if (iRST) begin      // Сброс
        state <= GPIO_5; // !!!
    end
    else begin
        case (state)
            GPIO_5:begin // Состояние ожидания прерывания (готовности) GPIO_5 от DSP
                oGPIO_0 <= 0;
                if (iGPIO5) begin
                    oSEL_CHANNEL <= iSEL_CHANNEL; // 
                    state        <= USEDW;
                end
                else begin
                    state <= GPIO_5;
                end
            end
            USEDW:begin // Состояние проверки заполненности (USEDW) FIFO для чтения (или сигнала окончания приема кадра)
                oDATA_UPP  <= 0;
                oACLR_FIFO <= 0;
                oGPIO_0    <= 0;
                if (rUSEDW > USEDW_VALUE) begin // if ((rUSEDW > 9'd49)&&(rGPIO_5)) begin
                    if (rFLAG_CONT) begin
                        oDATA_UPP <= iFIFO_OUT;
                        state     <= DATA_READ;
                    end
                    else begin
                        state <= FIFO_LATENCY;
                        oENA  <= 0;
                    end
                    oRD_REQ      <= 1;    // Запрос на чтение из FIFO
                    rLATENCY     <= 9'd1; // FIFO latency 3 ticks
                end
                else begin
                    rFLAG_CONT <= 0;
                    if (rSTART) begin
                        oDATA_UPP <= iFIFO_OUT;
                        state     <= DATA_READ;
                        rWORD_CNT <= rWORD_CNT + 9'd1;
                    end
                    else begin
                        state   <= USEDW;
                        oENA    <= 0;
                        oRD_REQ <= 0;    // !
                    end
                end
            end
            FIFO_LATENCY:begin // Состояние формирования задержки перед чтением (в параметрах FIFO)
                if (rLATENCY_CNT < rLATENCY - 9'd1) begin
                    rLATENCY_CNT <= rLATENCY_CNT + 9'd1;
                    state        <= FIFO_LATENCY;
                end
                else begin
                    state        <= DATA_READ;
                    rLATENCY_CNT <= 0;
                end
            end
            DATA_READ:begin // Состояние чтения пакетов из FIFO при заполненности FIFO до порога (USEDW),
                // либо при наличии сигнала окончания приема кадра по BLVDS
                if (rWORD_CNT < 9'd256) begin //256
                    oDATA_UPP <= iFIFO_OUT;
                    oENA      <= 1;
                    if (rWORD_CNT == 9'd255) begin //255
                        if (iEMPTY) begin // При опустошении FIFO
                            state      <= GPIO_0;
                            oRD_REQ    <= 0;
                            rSTART_RST <= 1;
                        end
                        else begin
                            rFLAG_CONT <= 1;
                            state      <= USEDW;
                        end
                        rWORD_CNT <= 0;
                    end
                    else begin
                        rWORD_CNT <= rWORD_CNT + 9'd1;
                        state     <= DATA_READ;
                    end
                end
                else begin
                    state     <= USEDW;
                    rWORD_CNT <= 0;
                    oRD_REQ   <= 0;
                end
            end
            GPIO_0:begin // Состояние формирования стимулирующих импульсов и GPIO_0
                rSTART_RST <= 0;
                rFLAG_CONT <= 0;
                oGPIO_0    <= 1;
                if (iGPIO5) begin
                    if (rGPIO0_CNT < CHECK_GPIO5) begin // Задержка во время проверки сброса GPIO5
                        rGPIO0_CNT <= rGPIO0_CNT + 9'd1;
                        oDATA_UPP  <= 0;
                        oENA       <= 0;
                    end
                    else begin // иначе формируем стимулирующее воздействие
                        rGPIO0_CNT <= 0;
                        state      <= GPIO_0;
                        oDATA_UPP  <= 16'h0000;
                        oENA       <= 1;
                    end
                end
                else begin // иначе если DSP сбросил GPIO_5
                    state      <= END_LATENCY;
                    oDATA_UPP  <= 0;
                    rGPIO0_CNT <= 0;
                    oENA       <= 0;
                end
            end
            END_LATENCY:begin // Состояние формирования задержки между чтениями кадров
                if (rEND_CNT < BETWEEN_FRAMES) begin // Задержка перед принятием нового кадра
                    rEND_CNT <= rEND_CNT + 9'd1;
                    state    <= END_LATENCY;
                    oGPIO_0  <= 0;
                end
                else begin
                    state    <= GPIO_5;
                    rEND_CNT <= 0;
                end
            end
        endcase
    end
end
endmodule
