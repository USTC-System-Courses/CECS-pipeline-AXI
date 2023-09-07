`timescale 1ns/1ps
`include "./include/config.sv"
module Hazard(
    // forwarding 
    input  logic [ 4:0] rf_rd_ls,
    input  logic [ 4:0] rf_rd_wb,
    input  logic [ 0:0] rf_we_ls,
    input  logic [ 0:0] rf_we_wb,
    input  logic [ 4:0] rf_rs1_ex,
    input  logic [ 4:0] rf_rs2_ex,
    input  logic [31:0] rf_wdata_tmp_ls,
    input  logic [31:0] rf_wdata_wb,

    output logic [ 0:0] forward1_en,
    output logic [ 0:0] forward2_en,
    output logic [31:0] forward1_data,
    output logic [31:0] forward2_data,

    // load-use
    input  logic [ 4:0] mem_access_ex,
    input  logic [ 4:0] rf_rd_ex,
    input  logic [ 4:0] rf_rs1_id,
    input  logic [ 4:0] rf_rs2_id,

    // cache miss
    input  logic [ 0:0] icache_miss,
    input  logic [ 0:0] dcache_miss,

    // control hazard
    input  logic [ 0:0] jump,
    input  logic [31:0] jump_target,
    input  logic [ 4:0] priv_vec_ex,
    input  logic [31:0] pc_ex,
    input  logic [ 4:0] priv_vec_wb,
    input  logic [31:0] pc_wb,
    input  logic [31:0] mepc_global,
    input  logic [31:0] mtvec_global,
    input  logic [31:0] mcause_global,

    // flush signals
    output logic [ 0:0] pc_set,
    output logic [ 0:0] IF1_IF2_flush,
    output logic [ 0:0] IF2_ID_flush,
    output logic [ 0:0] ID_EX_flush,
    output logic [ 0:0] EX_LS_flush,
    output logic [ 0:0] LS_WB_flush,
    output logic [ 0:0] icache_flush,

    // stall signals
    output logic [ 0:0] pc_stall,
    output logic [ 0:0] IF1_IF2_stall,
    output logic [ 0:0] IF2_ID_stall,
    output logic [ 0:0] ID_EX_stall,
    output logic [ 0:0] EX_LS_stall,
    output logic [ 0:0] LS_WB_stall,
    output logic [ 0:0] icache_stall,

    output logic [31:0] pc_set_target
);
    // forwarding
    always_comb begin
        forward1_en = 0;
        forward2_en = 0;
        forward1_data = 0;
        forward2_data = 0;
        if (rf_we_ls && rf_rd_ls == rf_rs1_ex) begin
            forward1_en = 1'b1;
            forward1_data = rf_wdata_tmp_ls;
        end
        else if (rf_we_wb && rf_rd_wb == rf_rs1_ex) begin
            forward1_en = 1'b1;
            forward1_data = rf_wdata_wb;
        end
        if (rf_we_ls && rf_rd_ls == rf_rs2_ex) begin
            forward2_en = 1'b1;
            forward2_data = rf_wdata_tmp_ls;
        end
        else if (rf_we_wb && rf_rd_wb == rf_rs2_ex) begin
            forward2_en = 1'b1;
            forward2_data = rf_wdata_wb;
        end
    end
    // load-use
    logic stall_by_load_use, flush_by_load_use;
    wire is_load_ex = mem_access_ex[`LOAD_BIT];
    always_comb begin
        stall_by_load_use = 0;
        flush_by_load_use = 0;
        if (is_load_ex && (rf_rd_ex == rf_rs1_id || rf_rd_ex == rf_rs2_id)) begin
            stall_by_load_use = 1'b1;
            flush_by_load_use = 1'b1;
        end
    end
    // cache miss
    wire stall_by_icache = icache_miss; 
    wire flush_by_icache = icache_miss; 
    wire stall_by_dcache = dcache_miss; 

    // control hazard
    wire flush_by_jump      = jump;
    wire flush_by_priv_ex   = |priv_vec_ex;
    wire flush_by_exp       = |mcause_global;

    assign pc_set           = flush_by_jump || flush_by_priv_ex || flush_by_exp;
    assign IF1_IF2_flush    = flush_by_jump || flush_by_priv_ex || flush_by_exp;
    assign IF2_ID_flush     = ((flush_by_jump || flush_by_icache) && !IF2_ID_stall) || flush_by_priv_ex || flush_by_exp;
    assign ID_EX_flush      = ((flush_by_jump || flush_by_load_use || flush_by_priv_ex) && !ID_EX_stall) || flush_by_exp;
    assign EX_LS_flush      = flush_by_exp;
    assign LS_WB_flush      = flush_by_exp;
    assign icache_flush     = flush_by_jump || flush_by_priv_ex || flush_by_exp;

    assign pc_stall         = stall_by_load_use || stall_by_icache || stall_by_dcache; 
    assign IF1_IF2_stall    = stall_by_load_use || stall_by_icache || stall_by_dcache;
    assign IF2_ID_stall     = stall_by_load_use || stall_by_dcache;
    assign ID_EX_stall      = stall_by_dcache;
    assign EX_LS_stall      = stall_by_dcache;
    assign LS_WB_stall      = stall_by_dcache;
    assign icache_stall     = stall_by_load_use || stall_by_dcache;

    always_comb begin
        pc_set_target = jump_target;
        if(flush_by_exp) begin
            pc_set_target = mtvec_global;
        end
        else if(flush_by_priv_ex) begin
            pc_set_target = priv_vec_ex[`MRET] ? mepc_global : pc_ex + 4;
        end
        else if (flush_by_jump) begin
            pc_set_target = jump_target;
        end
    end

endmodule
