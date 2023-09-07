`timescale 1ns/1ps
module SegReg_IF1_IF2#(
    parameter PC_RESET_VAL = 32'h0
)(
    input  logic [ 0:0] clk,
    input  logic [ 0:0] rstn,
    input  logic [ 0:0] stall,
    input  logic [ 0:0] flush,

    input  logic [31:0] pc_if1,
    output logic [31:0] pc_if2,
    input  logic [ 0:0] commit_if1,
    output logic [ 0:0] commit_if2
);
    always_ff @(posedge clk) begin
        if(!rstn || flush) begin
            pc_if2          <= PC_RESET_VAL;
            commit_if2      <= 1'b0;
        end 
        else if(!stall) begin
            pc_if2          <= pc_if1;
            commit_if2      <= commit_if1;
        end
    end

endmodule
