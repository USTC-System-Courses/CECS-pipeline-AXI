`timescale 1ns/1ps
`include "./include/config.sv"
module Exp_Commit(
    input  logic [ 4:0] priv_vec,
    output logic [31:0] exp_code
);
    always_comb begin
        exp_code = 0;
        if(priv_vec[`ECALL]) begin
            exp_code = 32'hb;
        end
    end
endmodule
