`timescale 1ns/1ps
`include "./include/config.sv"
module ALU(
    input  logic [31:0] sr1,
    input  logic [31:0] sr2,
    input  logic [ 4:0] alu_op,
    output logic [31:0] result
);
    logic [63:0] result_64;
    // multiply
    always_comb begin
        case(alu_op)
        `MUL:    result_64 = {{32{sr1[31]}}, sr1} * {{32{sr2[31]}}, sr2};
        `MULH:   result_64 = {{32{sr1[31]}}, sr1} * {{32{sr2[31]}}, sr2};
        `MULHSU: result_64 = {{32{sr1[31]}}, sr1} * {32'b0, sr2}; 
        `MULHU:  result_64 = {32'b0, sr1} * {32'b0, sr2};
        default: result_64 = 0;
        endcase
    end
    // divide, remainder
    logic   [31:0] result_div, result_rem;
    wire     [1:0] sign     = {sr1[31] ^ sr2[31], sr1[31]};
    wire    [31:0] sr1_abs  = sr1[31] ? -sr1 : sr1;
    wire    [31:0] sr2_abs  = sr2[31] ? -sr2 : sr2;
    always_comb begin
        case(alu_op)
        `DIV, `REM: begin
            result_div = sign[1] ? -(sr1_abs / sr2_abs) : sr1_abs / sr2_abs;
            result_rem = sign[0] ? -(sr1_abs % sr2_abs) : sr1_abs % sr2_abs;
        end
        `DIVU, `REMU: begin
            result_div = sr1 / sr2;
            result_rem = sr1 % sr2;
        end
        default: begin
            result_div = 0;
            result_rem = 0;
        end
        endcase
    end
    always_comb begin
        case(alu_op) 
        `ADD:                   result = sr1 + sr2;
        `SUB:                   result = sr1 - sr2;
        `AND:                   result = sr1 & sr2;
        `SLT:                   result = {31'b0, $signed(sr1) < $signed(sr2)};
        `SLTU:                  result = {31'b0, sr1 < sr2};
        `OR:                    result = sr1 | sr2;
        `XOR:                   result = sr1 ^ sr2;
        `SLL:                   result = sr1 << sr2[4:0];
        `SRL:                   result = sr1 >> sr2[4:0];
        `SRA:                   result = $signed(sr1) >>> sr2[4:0];
        `MUL:                   result = result_64[31:0];
        `MULH, `MULHSU, `MULHU: result = result_64[63:32];
        `DIV, `DIVU:            result = sr2 == 0 ? -1 : result_div;
        `REM, `REMU:            result = sr2 == 0 ? sr1 : result_rem;
        default:                result = 0;
        endcase
    end
endmodule
