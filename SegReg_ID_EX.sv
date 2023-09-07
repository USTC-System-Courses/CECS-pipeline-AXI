`timescale 1ns/1ps
module SegReg_ID_EX#(
    parameter PC_RESET_VAL = 32'h0
)(
    input  logic [ 0:0] clk,
    input  logic [ 0:0] rstn,
    input  logic [ 0:0] stall,
    input  logic [ 0:0] flush,

    input  logic [31:0] pc_id,
    input  logic [31:0] inst_id,
    input  logic [31:0] csr_rdata_id,
    input  logic [31:0] rdata1_id,
    input  logic [31:0] rdata2_id,
    input  logic [31:0] imm_id,
    input  logic [ 4:0] mem_access_id,
    input  logic [ 4:0] op_id,
    input  logic [ 4:0] br_type_id,
    input  logic [ 0:0] wb_rf_sel_id,
    input  logic [ 1:0] alu_rs1_sel_id,
    input  logic [ 1:0] alu_rs2_sel_id,
    input  logic [ 0:0] rf_we_id,
    input  logic [ 4:0] priv_vec_id,

    output logic [31:0] pc_ex,
    output logic [31:0] inst_ex,
    output logic [31:0] csr_rdata_ex,
    output logic [31:0] rdata1_ex,
    output logic [31:0] rdata2_ex,
    output logic [31:0] imm_ex,
    output logic [ 4:0] mem_access_ex,
    output logic [ 4:0] op_ex,
    output logic [ 4:0] br_type_ex,
    output logic [ 0:0] wb_rf_sel_ex,
    output logic [ 1:0] alu_rs1_sel_ex,
    output logic [ 1:0] alu_rs2_sel_ex,
    output logic [ 0:0] rf_we_ex,
    output logic [ 4:0] priv_vec_ex,

    input  logic [ 0:0] commit_id,
    output logic [ 0:0] commit_ex
);
    always_ff @(posedge clk) begin
        if(!rstn || flush) begin
            pc_ex           <= PC_RESET_VAL;
            inst_ex         <= 32'h13;
            csr_rdata_ex    <= 32'h0;
            rdata1_ex       <= 32'h0;
            rdata2_ex       <= 32'h0;
            imm_ex          <= 32'h0;
            mem_access_ex   <=  5'h0;
            op_ex           <=  5'h0;
            br_type_ex      <=  5'h0;
            wb_rf_sel_ex    <=  1'h0;
            alu_rs1_sel_ex  <=  2'h0;
            alu_rs2_sel_ex  <=  2'h0;
            rf_we_ex        <=  1'h0;
            priv_vec_ex     <=  5'h0;
            commit_ex       <=  1'h0;
        end 
        else if(!stall) begin
            pc_ex           <= pc_id;
            inst_ex         <= inst_id;
            csr_rdata_ex    <= csr_rdata_id;
            rdata1_ex       <= rdata1_id;
            rdata2_ex       <= rdata2_id;
            imm_ex          <= imm_id;
            mem_access_ex   <= mem_access_id;
            op_ex           <= op_id;
            br_type_ex      <= br_type_id;
            wb_rf_sel_ex    <= wb_rf_sel_id;
            alu_rs1_sel_ex  <= alu_rs1_sel_id;
            alu_rs2_sel_ex  <= alu_rs2_sel_id;
            rf_we_ex        <= rf_we_id;
            priv_vec_ex     <= priv_vec_id;
            commit_ex       <= commit_id;
        end
    end

endmodule
