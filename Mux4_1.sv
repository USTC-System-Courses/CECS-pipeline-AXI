
`timescale 1ns/1ps
module Mux4_1#(
    parameter WIDTH = 32
)(
    input  logic [WIDTH-1:0] din1,
    input  logic [WIDTH-1:0] din2,
    input  logic [WIDTH-1:0] din3,
    input  logic [WIDTH-1:0] din4,
    input  logic       [1:0] sel,
    output logic [WIDTH-1:0] dout
);
    always_comb begin
        case(sel)
            2'b00: dout = din1;
            2'b01: dout = din2;
            2'b10: dout = din3;
            2'b11: dout = din4;
        endcase
    end
endmodule
