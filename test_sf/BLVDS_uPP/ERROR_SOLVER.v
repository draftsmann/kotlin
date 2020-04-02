module ERROR_SOLVER
(
    input         iCLK,
    input         iFULL_ERROR,iHEAD_ERROR,iEPILOG_ERROR,

    output [15:0] oFULL_ERR_CNT,oHEAD_ERR_CNT,oEPILOG_ERR_CNT
);

    reg         rFULL_ERROR,rHEAD_ERROR,rEPILOG_ERROR;

ERR_CNT ERR_CNT_FULL (
    .clock ( iCLK ),
    .cnt_en ( rFULL_ERROR ),
    .q ( oFULL_ERR_CNT )
    );

ERR_CNT ERR_CNT_HEAD (
    .clock ( iCLK ),
    .cnt_en ( rHEAD_ERROR ),
    .q ( oHEAD_ERR_CNT )
    );

ERR_CNT ERR_CNT_EPILOG (
    .clock ( iCLK ),
    .cnt_en ( rEPILOG_ERROR ),
    .q ( oEPILOG_ERR_CNT )
    );

always @(posedge iCLK) begin
    rEPILOG_ERROR <= iEPILOG_ERROR;
    rFULL_ERROR   <= iFULL_ERROR;
    rHEAD_ERROR   <= iHEAD_ERROR;
end

endmodule