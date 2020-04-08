//==================================================================================================
//  Filename      : button_debouncer.v
//  Created On    : 2020-04-08 13:05:06
//  Last Modified : 2020-04-08 13:05:13
//  Revision      : 
//  Author        : 
//  Company       : AO Kotlin-Novator
//  Email         : 
//
//  Description   : 
//
//
//==================================================================================================
module button_debouncer
#(
    parameter CNT_WIDTH = 7
)
(
    input       iCLK,iRST,iSW,

    output  reg oSW_STATE,oSW_DOWN,oSW_UP
);
// ! Синхронизируем вход с текущим тактовым доменом
    reg [1:0]   rSW;
/////////////////////////////////////////
always @(posedge iCLK or posedge iRST)
    if (iRST)
        rSW <= 2'b00;
    else
        rSW <= {rSW[0], iSW}; // rSW <= {rSW[0], ~iSW};

    reg [CNT_WIDTH-1:0] rSW_COUNT;

    wire wSW_CHANGE_F = (oSW_STATE != rSW[1]);
    wire wSW_CNT_MAX  = &rSW_COUNT;
/////////////////////////////////////////
always @(posedge iCLK or posedge iRST)
    if (iRST) begin
        rSW_COUNT <= 0;
        oSW_STATE <= 0;
    end
    else if (wSW_CHANGE_F) begin
        if (wSW_CNT_MAX) oSW_STATE <= ~oSW_STATE;
        rSW_COUNT <= rSW_COUNT + 'd1;
    end
    else 
        rSW_COUNT <= 0;
/////////////////////////////////////////
always @(posedge iCLK) begin
    oSW_DOWN <= wSW_CHANGE_F & wSW_CNT_MAX & ~oSW_STATE;
    oSW_UP   <= wSW_CHANGE_F & wSW_CNT_MAX & oSW_STATE;
end

endmodule