//==================================================================================================
//  Filename      : Strob_cutter.v
//  Created On    : 2020-04-08 13:05:35
//  Last Modified : 2020-04-08 13:05:43
//  Revision      : 
//  Author        : 
//  Company       : AO Kotlin-Novator
//  Email         : 
//
//  Description   : 
//
//
//==================================================================================================
module Strob_cutter 
(
input       iclk,
input       ibutton,
output reg  o_start_str
);
//Logic
reg rdff; //Регистр защелка триггера
//Initial
initial begin
	rdff        = 1'b0;
	o_start_str = 1'b0;
end
//main
always @(posedge iclk) begin
	//Ждем начала строба
	if((ibutton)&(!rdff)) begin
	 o_start_str = 1'b1;
	 rdff = 1'b1;
	end
	else begin
	 o_start_str = 1'b0;
	end
	//Ждем окончания строба
	if(!ibutton) begin
	   rdff        = 1'b0;
	   o_start_str = 1'b0;
	end
end
endmodule 