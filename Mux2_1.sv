`timescale 1ns/1ps
module Mux2_1#(
    parameter WIDTH = 32
)(
    input  logic [WIDTH-1:0] din1,
    input  logic [WIDTH-1:0] din2,
    input  logic       [0:0] sel,
    output logic [WIDTH-1:0] dout
);
    always_comb begin
        case(sel)
            1'b0: dout = din1;
            1'b1: dout = din2;
        endcase
    end
endmodule

