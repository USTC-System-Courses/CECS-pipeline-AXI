`timescale 1ns/1ps
module NPC_Mux(
    input  logic [31:0] pc,
    input  logic [ 0:0] pc_set,
    input  logic [31:0] pc_target,
    output logic [31:0] next_pc
);
    assign next_pc = pc_set ? pc_target : pc + 4;
endmodule
