`timescale 1ns/1ps
module Priv(
    input  logic [ 2:0] csr_op,
    input  logic [31:0] csr_rdata,
    input  logic [31:0] rf_rdata1,
    input  logic [31:0] zimm,
    output logic [31:0] csr_wdata
);
    localparam 
        CSRRW   = 3'b001,
        CSRRS   = 3'b010,
        CSRRC   = 3'b011,
        CSRRWI  = 3'b101,
        CSRRSI  = 3'b110,
        CSRRCI  = 3'b111;
    always_comb begin
        case(csr_op)
        CSRRW:   csr_wdata = rf_rdata1;
        CSRRS:   csr_wdata = csr_rdata | rf_rdata1;
        CSRRC:   csr_wdata = csr_rdata & ~rf_rdata1;
        CSRRWI:  csr_wdata = zimm;
        CSRRSI:  csr_wdata = csr_rdata | zimm;
        CSRRCI:  csr_wdata = csr_rdata & ~zimm;
        default: csr_wdata = 0;
        endcase
    end
endmodule
