`timescale 1ns/1ps
`include "./include/config.sv"
module Branch(
    input  logic [ 4:0] br_type,
    input  logic [31:0] sr1,
    input  logic [31:0] sr2,
    input  logic [31:0] pc,
    input  logic [31:0] imm,
    output logic [ 0:0] jump,
    output logic [31:0] jump_target
);
    wire is_branch = br_type[4] && !br_type[3];
    wire is_jal    = br_type[4] && br_type[3] && br_type[2];
    wire is_jalr   = br_type[4] && br_type[3] && !br_type[2];
    always_comb begin
        if(is_branch) begin
            case(br_type[2:0])
            `BEQ: jump = sr1 == sr2;
            `BNE: jump = sr1 != sr2;
            `BLT: jump = $signed(sr1) < $signed(sr2);
            `BGE: jump = $signed(sr1) >= $signed(sr2);
            `BLTU: jump = sr1 < sr2;
            `BGEU: jump = sr1 >= sr2;
            default: jump = 0;
            endcase
        end
        else if(is_jal || is_jalr) begin
            jump = 1;
        end
        else begin
            jump = 0;
        end
    end

    always_comb begin
        if(is_jalr) begin
            jump_target = sr1 + imm;
        end
        else begin
            jump_target = pc + imm;
        end
    end
endmodule
