//==================================================================================================
//  Filename      : user_bcvs.v
//  Created On    : 2019-08-06 08:45:49
//  Last Modified : 2020-03-17 09:30:46
//  Revision      : 
//  Author        : kozhemyakin_rd
//  Company       : АО Котлин-Новатор
//  Email         : kozhemyakin_rd@kotlin-novator.ru
//
//  Description   : Передатчик ALTLVDS_TX в БЦВС (шина E). Пользовательский уровень.
//user_bcvs user_bcvs_inst
//(
//  .iclk(iclk_sig) ,   // input  iclk_sig
//  .ireset(ireset_sig) ,   // input  ireset_sig
//  .isig_initial(isig_initial_sig) ,   // input  isig_initial_sig
//  .iRe_sample(iRe_sample_sig) ,   // input [27:0] iRe_sample_sig
//  .format(format_sig) ,   // input [1:0] format_sig
//  .channels(channels_sig) ,   // input [3:0] channels_sig
//  .num_pack(num_pack_sig) ,   // input [15:0] num_pack_sig
//  .numOI(numOI_sig) , // input [15:0] numOI_sig
//  .numTIR(numTIR_sig) ,   // input [15:0] numTIR_sig
//  .lPPS(lPPS_sig) ,   // input [31:0] lPPS_sig
//  .Bcur(Bcur_sig) ,   // input [15:0] Bcur_sig
//  .Icur(Icur_sig) ,   // input [15:0] Icur_sig
//  .num_sample(num_sample_sig) ,   // input [15:0] num_sample_sig
//  .osig_init_sig(osig_init_sig_sig) , // output  osig_init_sig_sig
//  .oUser_data(oUser_data_sig)     // output [17:0] oUser_data_sig
//);
//==================================================================================================
module user_bcvs(

input             iclk,           // Сигнал тактирования
input             ireset,         // Сигнал сброса
input             isig_initial,   // Строб сигнал инициализации
input      [31:0] iIm_Re_sample,  // Входные данные
// DEBUG
input      [2:0]  format,         // Формат
// input      [1:0]  pack_cnt,       // Счётчик пакетов
input      [3:0]  channels,       // Каналы

input      [7:0]  num_pack,       // Количество пакетов в накоплении
input      [15:0] numOI,
input      [15:0] numTIR,
input      [31:0] lPPS,
input      [31:0] ARUSH,
input      [15:0] Bcur,
input      [15:0] Icur,
input      [7:0]  size_pack,     // Размер пакета, ЦМР = 2048

output reg        osig_init_sig,
output reg [15:0] oRd_addr_BLVDS,
output reg [17:0] oUser_data      // Выходные данные 18 бит
);
//Регистры
reg        [2:0]  state;          // Регистр состояния КА
reg        [9:0]  part_cnt;       // Внутренний счетчик для формирования заголовков
reg        [15:0] pack_cnt;
// reg        [31:0] rRe_sample;     // Регистр защиты отсчетов Re от перезаписи
reg        [15:0] sample_cnt;
reg        [17:0] rpack_crc;
reg        [17:0] rframe_crc;
reg        [1:0]  rframe_cnt;
reg               rflag_sel;
reg               rflag_sev;
reg        [15:0] num_sample;     // Количество выборок в пакете
reg        [15:0] rnum_sample;
reg        [5:0]  rdelay_frame;
reg        [7:0]  rnum_pack;

// reg               ren_frame_crc;
// HEADER 
localparam frame_head_1       = 3'b000,   // Признак первого слова в заголовке кадра 
           frame_head_2       = 3'b001,   // Признак второго слова в заголовке кадра 
           pack_head_1        = 3'b010,   // Признак первого слова в заголовке пакета 
           pack_head_2        = 3'b011;   // Признак второго слова в заголовке пакета 
// EPILOG     
localparam frame_epilog_1     = 3'b100,   // Признак первого слова в эпилоге кадра  
           frame_epilog_2     = 3'b101,   // Признак второго слова в эпилоге кадра 
           pack_epilog_1      = 3'b110,   // Признак первого слова в эпилоге пакета 
           pack_epilog_2      = 3'b111;   // Признак второго слова в эпилоге пакета 
// Состояния КА  
localparam init_send          = 3'b001,   // Инициализация передачи
           frame_head         = 3'b011,   // Пара слов заголовка кадра (000 и 001)
           sev_send           = 3'b010,
           pack_head          = 3'b110,   // Пара слов заголовка пакета (010 и 011) 
           data_send          = 3'b100,   // Передача данных 
           pack_epilog        = 3'b101,   // Пара слов эпилога пакета (110 и 111)
           frame_epilog       = 3'b111;   // Пара слов эпилога кадра (100 и 101)
           // reserve            = 2'b00;
// Начальная инициализация
initial begin
    state            <= init_send; // Начальное состояние (Инициализация)
    oUser_data       <= 18'h3FE00; // Установка выходных линий в соостояние sync
    part_cnt         <= 0; 
    // rRe_sample    = 0;
    osig_init_sig    <= 0;
    rflag_sel        <= 0;
    sample_cnt       <= 0;
    rpack_crc        <= 0;
    rframe_crc       <= 0;
    rflag_sev        <= 1; 
end
always @(posedge iclk or posedge ireset) begin
    if (ireset) begin
    // reset
        state         <= init_send;
        oUser_data    <= 18'h3FE00; // Установка выходных линий в соостояние sync
        rflag_sel     <= 0;
        part_cnt      <= 0;
        osig_init_sig <= 0;
        sample_cnt    <= 0;
    end
    else begin
        case (state)
            init_send:begin
                osig_init_sig <= 0;
                rflag_sel     <= 0;
                if (isig_initial) begin
                    rnum_pack    <= num_pack;
                    rdelay_frame <= 0;
                    state        <= frame_head;
                    num_sample   <= 256*size_pack; // 2048*size_pack
                    rnum_sample  <= (256*size_pack);//rnum_sample <= (2*size_pack) + 16'd8; // С учетом ПИВ (СЕВ/АРУШ)
                end
                else begin
                    state      <= init_send;
                    oUser_data <= 18'h3FE00;
                end
            end
            frame_head:begin
                if (part_cnt < 1) begin
                    oUser_data    <= {2'b11,frame_head_1,format,rframe_cnt,rnum_pack}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b11,frame_head_1,format,rframe_cnt,rnum_pack};
                    part_cnt      <= part_cnt + 10'b1;
                    rframe_cnt    <= rframe_cnt + 2'd1;
                    state         <= frame_head;
                    osig_init_sig <= 1; 
                end
                else begin
                    oUser_data <= {2'b11,frame_head_2,1'b0,channels,size_pack}; // Отправка слова заголовка кадра 001
                    rframe_crc <= rframe_crc + {2'b11,frame_head_2,1'b0,channels,size_pack};
                    part_cnt   <= 0;
                    state      <= pack_head;
                    rflag_sev  <= 1; 
                end
            end
            sev_send:begin
                if (part_cnt == 0) begin
                    oUser_data    <= {2'b01,numOI}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b01,numOI};
                    rpack_crc     <= rpack_crc + {2'b01,numOI};
                    part_cnt      <= part_cnt + 10'b1;
                    state         <= sev_send; 
                end
                else if (part_cnt == 1) begin
                    oUser_data    <= {2'b01,numTIR}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b01,numTIR};
                    rpack_crc     <= rpack_crc + {2'b01,numTIR};
                    part_cnt      <= part_cnt + 10'b1;
                    state         <= sev_send; 
                end
                else if (part_cnt == 2) begin
                    oUser_data    <= {2'b01,lPPS[31:16]}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b01,lPPS[31:16]};
                    rpack_crc     <= rpack_crc + {2'b01,lPPS[31:16]};
                    part_cnt      <= part_cnt + 10'b1;
                    state         <= sev_send; 
                end
                else if (part_cnt == 3) begin
                    oUser_data    <= {2'b01,lPPS[15:0]}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b01,lPPS[15:0]};
                    rpack_crc     <= rpack_crc + {2'b01,lPPS[15:0]};
                    part_cnt      <= part_cnt + 10'b1;
                    state         <= sev_send; 
                end
                else if (part_cnt == 4) begin
                    oUser_data    <= {2'b01,Bcur}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b01,Bcur};
                    rpack_crc     <= rpack_crc + {2'b01,Bcur};
                    part_cnt      <= part_cnt + 10'b1;
                    state         <= sev_send; 
                end
                else if (part_cnt == 5) begin
                    oUser_data    <= {2'b01,Icur}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b01,Icur};
                    rpack_crc     <= rpack_crc + {2'b01,Icur};
                    part_cnt      <= part_cnt + 10'b1;
                    state         <= sev_send; 
                end
                else if (part_cnt == 6) begin
                    oUser_data    <= {2'b01,ARUSH[31:16]}; // Отправка слова заголовка кадра 000
                    rframe_crc    <= rframe_crc + {2'b01,ARUSH[31:16]};
                    rpack_crc     <= rpack_crc + {2'b01,ARUSH[31:16]};
                    part_cnt      <= part_cnt + 10'b1;
                    state         <= sev_send; 
                end
                else begin
                    oUser_data <= {2'b01,ARUSH[15:0]}; // Отправка слова заголовка кадра 001
                    rframe_crc <= rframe_crc + {2'b01,ARUSH[15:0]};
                    rpack_crc  <= rpack_crc + {2'b01,ARUSH[15:0]};
                    part_cnt   <= 0;
                    state      <= data_send;
                    rflag_sel  <= rflag_sel + 1'b1;
                    rflag_sev  <= 0; // Обнуление флага для передачи индивидуального размера пакета СЕВ
                end
            end
            pack_head:begin
                if (part_cnt < 1) begin
                    part_cnt   <= part_cnt + 10'b1;
                    state      <= pack_head;
                    oUser_data <= {2'b11,pack_head_1,pack_cnt[4:0],rnum_sample[15:8]}; // Отправка слова заголовка пакета 010
                    rframe_crc <= rframe_crc + {2'b11,pack_head_1,pack_cnt[4:0],rnum_sample[15:8]};
                    rpack_crc  <= rpack_crc + {2'b11,pack_head_1,pack_cnt[4:0],rnum_sample[15:8]};
                end
                else begin
                    oUser_data     <= {2'b11,pack_head_2,3'b000,2'b00,rnum_sample[7:0]}; // Отправка слова заголовка пакета 011
                    rframe_crc     <= rframe_crc + {2'b11,pack_head_2,3'b000,2'b00,rnum_sample[7:0]};
                    rpack_crc      <= rpack_crc + {2'b11,pack_head_2,3'b000,2'b00,rnum_sample[7:0]};
                    part_cnt       <= 0;          
                    state          <= sev_send;
                    oRd_addr_BLVDS <= 0; // !!!!!!!!READ_RAM!!!!!!!!! 
                end
            end
            data_send:begin
                // Стандартный формат (32р на квадратуру)
                if (part_cnt < 1) begin
                    oUser_data <= {2'b01,iIm_Re_sample[31:16]}; // Re/Im выборка ПАЦ – старшая часть
                    rframe_crc <= rframe_crc + {2'b01,iIm_Re_sample[31:16]};
                    rpack_crc  <= rpack_crc + {2'b01,iIm_Re_sample[31:16]};
                    part_cnt   <= part_cnt + 10'b1;
                    sample_cnt <= sample_cnt + 16'd1;
                    state      <= data_send;    
                end
                else begin
                    if (sample_cnt == (num_sample - 16'd1)) begin
                        oUser_data <= {2'b01,iIm_Re_sample[15:0]}; // Re/Im выборка ПАЦ – младшая часть
                        rframe_crc <= rframe_crc + {2'b01,iIm_Re_sample[15:0]};
                        rpack_crc  <= rpack_crc + {2'b01,iIm_Re_sample[15:0]};
                        part_cnt   <= 0;
                        sample_cnt <= 0;
                        state      <= pack_epilog;
                    end
                    else begin
                        oUser_data     <= {2'b01,iIm_Re_sample[15:0]}; // Re/Im выборка ПАЦ – младшая часть
                        rframe_crc     <= rframe_crc + {2'b01,iIm_Re_sample[15:0]};
                        rpack_crc      <= rpack_crc + {2'b01,iIm_Re_sample[15:0]};
                        part_cnt       <= 0;
                        state          <= data_send;
                        sample_cnt     <= sample_cnt + 16'd1;
                        oRd_addr_BLVDS <= oRd_addr_BLVDS + 16'd1; // !!!!!!!!READ_RAM!!!!!!!!!
                    end
                end
            end
            pack_epilog:begin
                if (part_cnt < 1) begin
                    oUser_data <= {2'b11,pack_epilog_1,5'b00000,~(rpack_crc[15:8])}; // Отправка слова эпилога пакета 110
                    rframe_crc <= rframe_crc + {2'b11,pack_epilog_1,5'b00000,~(rpack_crc[15:8])};
                    part_cnt   <= part_cnt + 10'b1;
                    state      <= pack_epilog; 
                end
                else begin
                    rpack_crc  <= 0;
                    if (pack_cnt < rnum_pack - 1) begin // rnum_pack
                        oUser_data <= {2'b11,pack_epilog_2,5'b00000,~(rpack_crc[7:0])}; // Отправка слова эпилога пакета 111
                        rframe_crc <= rframe_crc + {2'b11,pack_epilog_2,5'b00000,~(rpack_crc[7:0])};
                        part_cnt   <= 0;
                        pack_cnt   <= pack_cnt + 16'd1;
                        state      <= pack_head;
                    end
                    else begin
                        oUser_data <= {2'b11,pack_epilog_2,5'b00000,~(rpack_crc[7:0])}; // Отправка слова эпилога пакета 111
                        rframe_crc <= rframe_crc + {2'b11,pack_epilog_2,5'b00000,~(rpack_crc[7:0])};
                        part_cnt   <= 0;
                        pack_cnt   <= 0;
                        state      <= frame_epilog;
                    end
                end
            end
            frame_epilog:begin
                if (part_cnt < 1) begin
                    oUser_data <= {2'b11,frame_epilog_1,5'b00000,~(rframe_crc[15:8])}; // Отправка слова эпилога кадра 100
                    part_cnt   <= part_cnt + 10'b1;
                    state      <= frame_epilog; 
                end
                else begin
                    oUser_data <= {2'b11,frame_epilog_2,5'b00000,~(rframe_crc[7:0])}; // Отправка слова эпилога кадра 101
                    part_cnt   <= 0;
                    state      <= init_send;
                    rframe_crc <= 0;
                end
            end
        endcase
    end
end
endmodule
