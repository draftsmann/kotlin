module BLVDS_RECEIVER 
(
    input               iCLK,
    input               iRST,
    input       [17:0]  iDATA_BLVDS,
    input               iWR_FULL,

    output  reg         oSEND_OK,
    output  reg         oWR_REQ,
    output  reg         oFULL_ERROR,oHEAD_ERROR,oEPILOG_ERROR,
    output  reg [15:0]  oDATA_BLVDS,
    output  reg         oSEL_CHANNEL,oACLR_FIFO
);
//Logic
    reg         [2:0]   rPART_CNT;
    reg         [4:0]   rWRFULL_CNT;
    reg         [2:0]   rFORMAT;
    reg         [1:0]   rFRAME_CNT;
    reg         [7:0]   rPACK_NUM;
    reg         [3:0]   rCHANNELS;
    reg         [7:0]   rPACK_SIZE;
    reg         [4:0]   rPACK_CNT;
    reg         [15:0]  rSAMPLE_NUM;
    reg         [15:0]  rSERVICE_CNT;
    reg         [7:0]   rPACK_COUNT;
    reg         [15:0]  rPACK_CRC;
    reg         [15:0]  rFRAME_CRC;
    reg         [17:0]  rCALC_CRC;
    reg         [15:0]  rSAMPLE_CNT;
    reg         [7:0]   rFRAME_DELAY;

// Declare the state register to be "safe" to implement
// a safe state machine that can recover gracefully from
// an illegal state (by returning to the reset state).
    (* syn_encoding = "safe" *) reg [2:0] state;

// Declare states
    localparam HEAD_WORDS   = 0, // Состояние ожидания заголовков
               EPILOG_WORDS = 1, // Состояние ожидания эпилогов
               DATA_RECEIVE = 2, // Состояние приема пакетов
               END_FRAME    = 3, // Состояние обработки принятой и расчитанной CRC
               COLLISION    = 4, // Состояние отработки коллизий приема
               LATENCY      = 5; // Состояние задержки перед приемом нового кадра
// Начальная инициализация
initial begin
    state        = HEAD_WORDS; // !!!
    oWR_REQ      = 0;
    oSEL_CHANNEL = 0;
    rFORMAT      = 0;
    rFRAME_CNT   = 0;
    rPACK_NUM    = 0;
    rCHANNELS    = 0;
    rPACK_SIZE   = 0;
    rPACK_CNT    = 0;
    rSAMPLE_NUM  = 0;
    rSERVICE_CNT = 0;
    rPACK_CRC    = 0;
    rFRAME_CRC   = 0;
    rCALC_CRC    = 0;
    rSAMPLE_CNT  = 0;
    rPART_CNT    = 0;
    rFRAME_DELAY = 0;
end
always @(posedge iCLK) begin
    if ((iWR_FULL)&&(!oACLR_FIFO)) begin // При сбросе наблюдается установление wrfull в FIFO !!!
        if (rWRFULL_CNT < 5'd30) begin
            rWRFULL_CNT <= rWRFULL_CNT + 5'd1;
        end
        else begin
            rWRFULL_CNT <= 0;
            oFULL_ERROR <= 1;
        end
    end
    else begin
        oFULL_ERROR <= 0;
        rWRFULL_CNT <= 0;
    end
end
// Main
always @(posedge iCLK or posedge iRST) begin
    if (iRST) begin
        // reset
        state        <= HEAD_WORDS; // !!!
        oWR_REQ      <= 0;
        oSEL_CHANNEL <= 0;
        rFORMAT      <= 0;
        rFRAME_CNT   <= 0;
        rCALC_CRC    <= 0;
        rPACK_NUM    <= 0;
        rCHANNELS    <= 0;
        rPACK_SIZE   <= 0;
        rPACK_CNT    <= 0;
        rSAMPLE_NUM  <= 0;
        rSERVICE_CNT <= 0;
        rPACK_CRC    <= 0;
        rFRAME_CRC   <= 0;
        rSAMPLE_CNT  <= 0;
        rPART_CNT    <= 0;
        rFRAME_DELAY <= 0;
    end
    else
        case (state)
            HEAD_WORDS:begin // Состояние ожидания заголовков
                if (iDATA_BLVDS[17:16] == 2'b11) begin // Идентификация служебных слов
                    oSEND_OK   <= 0;
						  oACLR_FIFO <= 0;
                    if (iDATA_BLVDS[17:0] == 18'h3FE00) begin
                        oDATA_BLVDS  <= 0;
//                        oACLR_FIFO   <= 0; // oACLR_FIFO   <= 1;
                        state        <= HEAD_WORDS;
                        rSERVICE_CNT <= 0;
                    end
                    else begin
                        oDATA_BLVDS <= iDATA_BLVDS[15:0];
//                        oACLR_FIFO  <= 0;
                        //////////////////////////////////////////////////////////////////////////////////////////
                        //////////////////////////////////////// Заголовки ///////////////////////////////////////
                        //////////////////////////////////////////////////////////////////////////////////////////
                        if ((iDATA_BLVDS[15:13] == 3'b000)&&(rSERVICE_CNT == 16'd0)) begin // Признак первого слова в заголовке кадра 
                            rFORMAT      <= iDATA_BLVDS[12:10];   // Формат
                            rFRAME_CNT   <= iDATA_BLVDS[9:8];     // Счётчик кадров
                            rPACK_NUM    <= iDATA_BLVDS[7:0];     // Количество пакетов/дорожек дальности
                            oWR_REQ      <= 1; // Сигнал разрешения записи в FIFO
                            rCALC_CRC    <= rCALC_CRC + iDATA_BLVDS;
                            rSERVICE_CNT <= rSERVICE_CNT + 16'd1;
                        end
                        else if ((iDATA_BLVDS[15:13] == 3'b001)&&(rSERVICE_CNT == 16'd1)) begin // Признак второго слова в заголовке кадра 
                            rCHANNELS    <= iDATA_BLVDS[11:8];         // Каналы
                            rPACK_SIZE   <= iDATA_BLVDS[7:0];          // Размер пакета ЦМР = 2048 (Режим/масштаб)
                            rCALC_CRC    <= rCALC_CRC + iDATA_BLVDS;
                            rSERVICE_CNT <= rSERVICE_CNT + 16'd1;
                        end
                        else if ((iDATA_BLVDS[15:13] == 3'b010)&&(rSERVICE_CNT == 16'd2)) begin // Признак первого слова в заголовке пакета 
                            rPACK_CNT         <= iDATA_BLVDS[12:8]; // Счётчик пакетов
                            rSAMPLE_NUM[15:8] <= iDATA_BLVDS[7:0];  // Старшая часть количества выборок в пакете
                            rCALC_CRC         <= rCALC_CRC + iDATA_BLVDS;
                            rSERVICE_CNT      <= rSERVICE_CNT + 16'd1;
                        end
                        else if ((iDATA_BLVDS[15:13] == 3'b011)&&(rSERVICE_CNT == 16'd3)) begin // Признак второго слова в заголовке пакета 
                            rSAMPLE_NUM[7:0] <= iDATA_BLVDS[7:0];   // Младшая часть количества выборок в пакете
                            state            <= DATA_RECEIVE;
                            rCALC_CRC        <= rCALC_CRC + iDATA_BLVDS;
                            rSERVICE_CNT     <= rSERVICE_CNT + 16'd1;
                        end
                        else begin
                            state       <= COLLISION;
                            oHEAD_ERROR <= 1;
                        end
                    end
                end
                else begin
                    state <= HEAD_WORDS;
                end
            end
            EPILOG_WORDS:begin // Состояние ожидания эпилогов
                oDATA_BLVDS <= iDATA_BLVDS[15:0]; // Выдача данных с FIFO в шину uPP
                //////////////////////////////////////////////////////////////////////////////////////////
                //////////////////////////////////////// Эпилоги /////////////////////////////////////////
                //////////////////////////////////////////////////////////////////////////////////////////
                if ((iDATA_BLVDS[15:13] == 3'b110)&&(rSERVICE_CNT == 16'd4)) begin // Признак первого слова в эпилоге пакета 
                    rPACK_CRC [15:8] <= iDATA_BLVDS[7:0];    // Старшая часть контрольной суммы в пакете
                    rCALC_CRC        <= rCALC_CRC + iDATA_BLVDS;
                    rSERVICE_CNT     <= rSERVICE_CNT + 16'd1;
                end
                else if ((iDATA_BLVDS[15:8] == 8'b11100000)&&(rSERVICE_CNT == 16'd5)) begin // Признак второго слова в эпилоге пакета 
                    if (rPACK_COUNT == rPACK_NUM) begin 
                        rSERVICE_CNT <= rSERVICE_CNT + 16'd1;
                        rPACK_COUNT  <= 0;
                        state        <= EPILOG_WORDS;
                    end
                    else begin
                        rSERVICE_CNT <= 16'd2;
                        state        <= HEAD_WORDS;
                    end
                    rPACK_CRC [7:0]  <= iDATA_BLVDS[7:0];    // Младшая часть контрольной суммы в пакете
                    rCALC_CRC        <= rCALC_CRC + iDATA_BLVDS;
                end
                else if ((iDATA_BLVDS[15:8] == 8'b10000000)&&(rSERVICE_CNT == 16'd6)) begin // Признак первого слова в эпилоге кадра 
                    rFRAME_CRC [15:8] <= iDATA_BLVDS[7:0];   // Старшая часть контрольной суммы в кадре
                    rSERVICE_CNT      <= rSERVICE_CNT + 16'd1;
                end
                else if ((iDATA_BLVDS[15:13] == 3'b101)&&(rSERVICE_CNT == 16'd7)) begin // Признак второго слова в эпилоге кадра 
                    rFRAME_CRC [7:0]  <= iDATA_BLVDS[7:0];   // Младшая часть контрольной суммы в кадре
                    state             <= END_FRAME;
                    rSERVICE_CNT      <= 0;
                end
                else begin
                    state         <= COLLISION;
                    oEPILOG_ERROR <= 1;
                end
            end
            DATA_RECEIVE:begin // Состояние приема пакетов
                oDATA_BLVDS <= iDATA_BLVDS[15:0];
                rCALC_CRC   <= rCALC_CRC + iDATA_BLVDS;
                if (rSAMPLE_CNT < (rSAMPLE_NUM + 16'd7)) begin
                    rSAMPLE_CNT <= rSAMPLE_CNT + 16'd1;
                    state       <= DATA_RECEIVE;
                end
                else begin
                    rSAMPLE_CNT  <= 0;
                    rPACK_COUNT  <= rPACK_COUNT + 8'd1;
                    state        <= EPILOG_WORDS;
                end
            end
            END_FRAME:begin // Состояние обработки принятой и расчитанной CRC
                if (rPART_CNT < 3'd3) begin
                    state       <= END_FRAME;
                    rPART_CNT   <= rPART_CNT + 3'd1;
                    if (rPART_CNT == 3'd0) begin
                        oDATA_BLVDS <= rFRAME_CRC; // Запись в FIFO принятой CRC
                    end
                    if (rPART_CNT == 3'd1) begin
                        oDATA_BLVDS <= ~(rCALC_CRC[15:0]); // Запись в FIFO расчитанной CRC
                    end
                    else if (rPART_CNT == 3'd2) begin
                        if (rFRAME_CRC == ~(rCALC_CRC[15:0])) begin
                            oDATA_BLVDS <= 16'h00F1; // Признак корректности CRC
                        end
                        else begin
                            oDATA_BLVDS <= 16'h00F0; // Признак некорректности CRC
                        end
                    end
                end
                else begin
                    state        <= LATENCY;
                    oSEND_OK     <= 1;
                    rSERVICE_CNT <= 0;
                    oWR_REQ      <= 0; // Сигнал разрешения записи в FIFO
                    rCALC_CRC    <= 0;
                    rPART_CNT    <= 0;
                end
            end
            COLLISION:begin // Состояние отработки коллизий приема
                oDATA_BLVDS  <= 0;
					 oWR_REQ      <= 0;
					 rSERVICE_CNT <= 0;
					 if (rFRAME_DELAY < 8'd100) begin
                    rFRAME_DELAY <= rFRAME_DELAY + 8'd1;
                    oSEND_OK     <= 1;
                end
                else begin
                    if (iDATA_BLVDS[17:0] == 18'h3FE00) begin
                        state         <= HEAD_WORDS;
								oSEND_OK      <= 0;
                        oHEAD_ERROR   <= 0;
                        oEPILOG_ERROR <= 0;
                    end
                    else begin
                        state <= COLLISION;
                    end
                    rFRAME_DELAY <= 0;
                    rSERVICE_CNT <= 0;
                    rCALC_CRC    <= 0;
                    oACLR_FIFO   <= 1; // ???
                end
            end
            LATENCY:begin // Состояние задержки перед приемом нового кадра
                if (rFRAME_DELAY < 8'd100) begin
                    rFRAME_DELAY <= rFRAME_DELAY + 8'd1;
                end
                else begin
                    rFRAME_DELAY <= 0; 
                    oSEL_CHANNEL <= ~oSEL_CHANNEL; // Смена канала для записи нового кадра
						  oACLR_FIFO   <= 1;
                    state        <= HEAD_WORDS;
                end
            end
        endcase
end
endmodule 