`timescale 1ns/1ps
`include "./include/config.sv"
module CPU#(
    parameter PC_RESET_VALUE    = 32'h80000000,
    parameter INDEX_WIDTH       = 4,
    parameter WORD_OFFSET_WIDTH = 2
)(
    input  logic [   0:0] clk,
    input  logic [   0:0] rstn,

    // AR
    output logic [31:0] araddr,
    output logic [ 0:0] arvalid,
    input  logic [ 0:0] arready,
    output logic [ 7:0] arlen,
    output logic [ 2:0] arsize,
    output logic [ 1:0] arburst,

    // R
    input  logic [31:0] rdata,
    input  logic [ 1:0] rresp,
    input  logic [ 0:0] rvalid,
    output logic [ 0:0] rready,
    input  logic [ 0:0] rlast,

    // AW
    output logic [31:0] awaddr,
    output logic [ 0:0] awvalid,
    input  logic [ 0:0] awready,
    output logic [ 7:0] awlen,
    output logic [ 2:0] awsize,
    output logic [ 1:0] awburst,

    // W
    output logic [31:0] wdata,
    output logic [ 3:0] wstrb,
    output logic [ 0:0] wvalid,
    input  logic [ 0:0] wready,
    output logic [ 0:0] wlast,

    // B
    input  logic [ 1:0] bresp,
    input  logic [ 0:0] bvalid,
    output logic [ 0:0] bready,

    output logic [ 0:0] commit_wb,
    output logic [ 0:0] uncache_read_wb,
    output logic [31:0] inst,
    output logic [31:0] pc_cur
`ifdef DEBUG
    ,
    output logic [1023:0] rf_diff,
    output logic          putchar,
    output         [ 7:0] c
`endif
);

    /* IF1 stage */
    logic [31:0]    pc_if1, pc_if2, pc_id, pc_ex, pc_ls, pc_wb;
    logic [31:0]    inst_if2, inst_id, inst_ex, inst_ls, inst_wb;
    logic [31:0]    pc_target, next_pc;
    logic [31:0]    imm_id, imm_ex;
    logic [31:0]    rf_wdata_wb;
    logic [31:0]    csr_rdata_id, csr_rdata_ex;
    logic [31:0]    csr_wdata_ex, csr_wdata_ls, csr_wdata_wb;
    logic [31:0]    rf_rdata1_id, rf_rdata1_ex;
    logic [31:0]    rf_rdata2_id, rf_rdata2_ex;
    logic [31:0]    forward1_data, forward2_data;
    logic [31:0]    alu_rf_data1, alu_rf_data2;
    logic [31:0]    alu_rs1, alu_rs2;
    logic [31:0]    alu_result_ex, alu_result_ls, alu_result_wb;
    logic [31:0]    jump_target;
    logic [31:0]    mem_wdata_ex;
    logic [31:0]    mem_rdata_ls, mem_rdata_wb; 
    logic [31:0]    dcache_rdata_ls;
    logic [31:0]    i_raddr, i_rdata, d_raddr, d_rdata, d_waddr, d_wdata;
    logic [31:0]    mepc_global, mtvec_global, mcause_global;
    logic [ 7:0]    i_rlen, d_rlen, d_wlen;
    logic [ 4:0]    alu_op_id, alu_op_ex;
    logic [ 4:0]    mem_access_id, mem_access_ex, mem_access_ls;
    logic [ 4:0]    br_type_id, br_type_ex;
    logic [ 4:0]    priv_vec_id, priv_vec_ex, priv_vec_ls, priv_vec_wb;
    logic [ 3:0]    wstrb_ex, d_wstrb;
    logic [ 2:0]    i_rsize, d_rsize, d_wsize;
    logic [ 1:0]    alu_rs1_sel_id, alu_rs1_sel_ex;
    logic [ 1:0]    alu_rs2_sel_id, alu_rs2_sel_ex;
    logic [ 0:0]    wb_rf_sel_id, wb_rf_sel_ex, wb_rf_sel_ls, wb_rf_sel_wb;
    logic [ 0:0]    rf_we_id, rf_we_ex, rf_we_ls, rf_we_wb;

    logic [ 0:0]    ip_rvalid_if1;
    logic [ 0:0]    i_rvalid, i_rready, i_rlast;
    logic [ 0:0]    d_rvalid, d_rready, d_rlast;
    logic [ 0:0]    d_wvalid, d_wready, d_wlast;
    logic [ 0:0]    d_bvalid, d_bready;

    logic [ 0:0]    forward1_en, forward2_en;
    logic [ 0:0]    jump;
    logic [ 0:0]    pc_set, pc_stall;
    logic [ 0:0]    IF1_IF2_stall, IF1_IF2_flush;
    logic [ 0:0]    IF2_ID_stall, IF2_ID_flush;
    logic [ 0:0]    ID_EX_stall, ID_EX_flush;
    logic [ 0:0]    EX_LS_stall, EX_LS_flush;
    logic [ 0:0]    LS_WB_stall, LS_WB_flush;
    logic [ 0:0]    icache_stall, icache_flush, icache_miss, dcache_miss;

    logic [ 0:0]    commit_if1, commit_if2, commit_id, commit_ex, commit_ls;

    assign ip_rvalid_if1 = rstn;
    assign commit_if1 = rstn;
    assign pc_cur = pc_wb;
    assign inst = inst_wb;
    NPC_Mux  NPC_Mux_inst (
        .pc         (pc_if1),
        .pc_set     (pc_set),
        .pc_target  (pc_target),
        .next_pc    (next_pc)
    );

    PC#(
        .RESET_VALUE(PC_RESET_VALUE)
    ) PC_inst (
        .clk        (clk),
        .rstn       (rstn),
        .stall      (pc_stall),
        .next_pc    (next_pc),
        .pc_set     (pc_set),
        .pc         (pc_if1)
    );


    /* IF1-IF2 segreg */
    SegReg_IF1_IF2 # (
        .PC_RESET_VAL(PC_RESET_VALUE)
    ) SegReg_IF1_IF2_inst (
        .clk                (clk),
        .rstn               (rstn),
        .stall              (IF1_IF2_stall),
        .flush              (IF1_IF2_flush),
        .pc_if1             (pc_if1),
        .pc_if2             (pc_if2),
        .commit_if1         (commit_if1),
        .commit_if2         (commit_if2)
    );
    ICache # (
        .INDEX_WIDTH(INDEX_WIDTH),
        .WORD_OFFSET_WIDTH(WORD_OFFSET_WIDTH)
    )ICache_inst (
        .clk                (clk),
        .rstn               (rstn),
        .rvalid             (ip_rvalid_if1),
        .raddr              (pc_if1),
        .rdata              (inst_if2),
        .fencei_valid       (priv_vec_ex[`FENCEI]),
        .fence_valid        (priv_vec_ex[`FENCE]),
        .flush              (icache_flush),
        .stall              (icache_stall),
        .i_rvalid           (i_rvalid),
        .i_rready           (i_rready),
        .i_raddr            (i_raddr),
        .i_rdata            (i_rdata),
        .i_rlast            (i_rlast),
        .i_rsize            (i_rsize),
        .i_rlen             (i_rlen),
        .icache_miss        (icache_miss)
    );

    /* IF2 stage */
    /* IF2-ID segreg */
    SegReg_IF2_ID # (
        .PC_RESET_VAL(PC_RESET_VALUE)
    ) SegReg_IF2_ID_inst (
        .clk            (clk),
        .rstn           (rstn),
        .stall          (IF2_ID_stall),
        .flush          (IF2_ID_flush),
        .pc_if2         (pc_if2),
        .inst_if2       (inst_if2),
        .pc_id          (pc_id),
        .inst_id        (inst_id),
        .commit_if2     (commit_if2),
        .commit_id      (commit_id)
    );

    /* ID stage */
    Decode  Decode_inst (
        .inst           (inst_id),
        .alu_op         (alu_op_id),
        .mem_access     (mem_access_id),
        .imm            (imm_id),
        .rf_we          (rf_we_id),
        .alu_rs1_sel    (alu_rs1_sel_id),
        .alu_rs2_sel    (alu_rs2_sel_id),
        .wb_rf_sel      (wb_rf_sel_id),
        .br_type        (br_type_id),
        .priv_vec       (priv_vec_id)
    );
    Regfile  Regfile_inst (
        .clk            (clk),
        .raddr1         (inst_id[19:15]),
        .raddr2         (inst_id[24:20]),
        .waddr          (inst_wb[11:7]),
        .wdata          (rf_wdata_wb),
        .we             (rf_we_wb),
        .rdata1         (rf_rdata1_id),
        .rdata2         (rf_rdata2_id)
`ifdef DEBUG
        ,
        .rf_diff        (rf_diff)
`endif
    );
    CSR  CSR_inst (
        .clk            (clk),
        .rstn           (rstn),
        .raddr          (inst_id[31:20]),
        .waddr          (inst_wb[31:20]),
        .we             (priv_vec_wb[`CSR_RW]), 
        .wdata          (csr_wdata_wb),
        .rdata          (csr_rdata_id),

        .mepc_out       (mepc_global),
        .pc_wb          (pc_wb),
        .mtvec_out      (mtvec_global),
        .mcause_in      (mcause_global),
        .priv_vec_wb    (priv_vec_wb)
    );

    /* ID-EX segreg */
    SegReg_ID_EX # (
        .PC_RESET_VAL(PC_RESET_VALUE)
    ) SegReg_ID_EX_inst (
        .clk            (clk),
        .rstn           (rstn),
        .stall          (ID_EX_stall),
        .flush          (ID_EX_flush),
        .pc_id          (pc_id),
        .inst_id        (inst_id),
        .csr_rdata_id   (csr_rdata_id),
        .rdata1_id      (rf_rdata1_id),
        .rdata2_id      (rf_rdata2_id),
        .imm_id         (imm_id),
        .mem_access_id  (mem_access_id),
        .op_id          (alu_op_id),
        .br_type_id     (br_type_id),
        .wb_rf_sel_id   (wb_rf_sel_id),
        .alu_rs1_sel_id (alu_rs1_sel_id),
        .alu_rs2_sel_id (alu_rs2_sel_id),
        .rf_we_id       (rf_we_id),
        .priv_vec_id    (priv_vec_id),
        .pc_ex          (pc_ex),
        .inst_ex        (inst_ex),
        .csr_rdata_ex   (csr_rdata_ex),
        .rdata1_ex      (rf_rdata1_ex),
        .rdata2_ex      (rf_rdata2_ex),
        .imm_ex         (imm_ex),
        .mem_access_ex  (mem_access_ex),
        .op_ex          (alu_op_ex),
        .br_type_ex     (br_type_ex),
        .wb_rf_sel_ex   (wb_rf_sel_ex),
        .alu_rs1_sel_ex (alu_rs1_sel_ex),
        .alu_rs2_sel_ex (alu_rs2_sel_ex),
        .rf_we_ex       (rf_we_ex),
        .priv_vec_ex    (priv_vec_ex),
        .commit_id      (commit_id),
        .commit_ex      (commit_ex)
    );

    /* EX stage */
    Mux2_1 # (
        .WIDTH(32)
    )   ALU_rf_data1_mux (
        .din1           (rf_rdata1_ex),
        .din2           (forward1_data),
        .sel            (forward1_en),
        .dout           (alu_rf_data1)
    );
    Mux2_1 # (
        .WIDTH(32)
    )   ALU_rf_data2_mux (
        .din1           (rf_rdata2_ex),
        .din2           (forward2_data),
        .sel            (forward2_en),
        .dout           (alu_rf_data2)
    );
    Mux4_1 # (
        .WIDTH(32)
    )   ALU_rs1_mux (
        .din1           (alu_rf_data1),
        .din2           (pc_ex),
        .din3           (32'h0),
        .din4           (32'h0),
        .sel            (alu_rs1_sel_ex),
        .dout           (alu_rs1)
    );
    Mux4_1 # (
        .WIDTH(32)
    )   ALU_rs2_mux (
        .din1           (alu_rf_data2),
        .din2           (imm_ex),
        .din3           (32'h4),
        .din4           (csr_rdata_ex),
        .sel            (alu_rs2_sel_ex),
        .dout           (alu_rs2)
    );

    ALU  ALU_inst (
        .sr1            (alu_rs1),
        .sr2            (alu_rs2),
        .alu_op         (alu_op_ex),
        .result         (alu_result_ex)
    );

    Priv  Priv_inst (
        .csr_op         (inst_ex[14:12]),
        .csr_rdata      (csr_rdata_ex),
        .rf_rdata1      (alu_rf_data1),
        .zimm           ({27'b0, inst_ex[19:15]}),
        .csr_wdata      (csr_wdata_ex)
    );

    Branch  Branch_inst (
        .br_type        (br_type_ex),
        .sr1            (alu_rf_data1),
        .sr2            (alu_rf_data2),
        .pc             (pc_ex),
        .imm            (imm_ex),
        .jump           (jump),
        .jump_target    (jump_target)
    );
    DCache_Write_Ctrl  DCache_Write_Ctrl_inst (
        .wdata          (alu_rf_data2),
        .mem_waddr      (alu_result_ex),
        .mem_access     (mem_access_ex),
        .wstrb          (wstrb_ex),
        .mem_wdata      (mem_wdata_ex)
    );

    /* EX-LS segreg */
    SegReg_EX_LS # (
        .PC_RESET_VAL(PC_RESET_VALUE)
    ) SegReg_EX_LS_inst (
        .clk            (clk),
        .rstn           (rstn),
        .stall          (EX_LS_stall),
        .flush          (EX_LS_flush),
        .pc_ex          (pc_ex),
        .inst_ex        (inst_ex),
        .priv_vec_ex    (priv_vec_ex),
        .csr_wdata_ex   (csr_wdata_ex),
        .alu_result_ex  (alu_result_ex),
        .mem_access_ex  (mem_access_ex),
        .wb_rf_sel_ex   (wb_rf_sel_ex),
        .rf_we_ex       (rf_we_ex),
        .pc_ls          (pc_ls),
        .inst_ls        (inst_ls),
        .priv_vec_ls    (priv_vec_ls),
        .csr_wdata_ls   (csr_wdata_ls),
        .alu_result_ls  (alu_result_ls),
        .mem_access_ls  (mem_access_ls),
        .wb_rf_sel_ls   (wb_rf_sel_ls),
        .rf_we_ls       (rf_we_ls),
        .commit_ex      (commit_ex),
        .commit_ls      (commit_ls)
    );

    DCache # (
        .INDEX_WIDTH(INDEX_WIDTH),
        .WORD_OFFSET_WIDTH(WORD_OFFSET_WIDTH)
    ) DCache_inst (
        .clk            (clk),
        .rstn           (rstn),
        .addr           (alu_result_ex),
        .rvalid         (mem_access_ex[`LOAD_BIT]),
        .rdata          (dcache_rdata_ls),
        .rsize          (mem_access_ex[2:0]),
        .wvalid         (mem_access_ex[`STORE_BIT]),
        .wdata          (mem_wdata_ex),
        .wstrb          (wstrb_ex),
        .fencei_valid   (priv_vec_ex[`FENCEI]),
        .fence_valid    (priv_vec_ex[`FENCE]),
        .d_rvalid       (d_rvalid),
        .d_rready       (d_rready),
        .d_raddr        (d_raddr),
        .d_rdata        (d_rdata),
        .d_rlast        (d_rlast),
        .d_rsize        (d_rsize),
        .d_rlen         (d_rlen),
        .d_wvalid       (d_wvalid),
        .d_wready       (d_wready),
        .d_waddr        (d_waddr),
        .d_wdata        (d_wdata),
        .d_wstrb        (d_wstrb),
        .d_wlast        (d_wlast),
        .d_wsize        (d_wsize),
        .d_wlen         (d_wlen),
        .d_bvalid       (d_bvalid),
        .d_bready       (d_bready),
        .dcache_miss    (dcache_miss)
    );
    /* LS stage */
    DCache_Read_Ctrl  DCache_Read_Ctrl_inst (
        .mem_rdata      (dcache_rdata_ls),
        .mem_raddr      (alu_result_ls),
        .mem_access     (mem_access_ls),
        .rdata          (mem_rdata_ls)
    );
    /* LS-WB segreg */
    SegReg_LS_WB # (
        .PC_RESET_VAL(PC_RESET_VALUE)
    ) SegReg_LS_WB_inst (
        .clk                (clk),
        .rstn               (rstn),
        .stall              (LS_WB_stall),
        .flush              (LS_WB_flush),
        .pc_ls              (pc_ls),
        .inst_ls            (inst_ls),
        .alu_result_ls      (alu_result_ls),
        .mem_rdata_ls       (mem_rdata_ls),
        .priv_vec_ls        (priv_vec_ls),
        .csr_wdata_ls       (csr_wdata_ls),
        .wb_rf_sel_ls       (wb_rf_sel_ls),
        .rf_we_ls           (rf_we_ls),
        .pc_wb              (pc_wb),
        .inst_wb            (inst_wb),
        .alu_result_wb      (alu_result_wb),
        .mem_rdata_wb       (mem_rdata_wb),
        .priv_vec_wb        (priv_vec_wb),
        .csr_wdata_wb       (csr_wdata_wb),
        .wb_rf_sel_wb       (wb_rf_sel_wb),
        .rf_we_wb           (rf_we_wb),
        .commit_ls          (commit_ls),
        .commit_wb          (commit_wb),
        .read_ls            (mem_access_ls[`LOAD_BIT]),
        .uncache_read_wb    (uncache_read_wb)
    );

    /* WB stage */
    Mux2_1 # (
        .WIDTH(32)
    )   WB_rf_wdata_mux (
        .din1           (alu_result_wb),
        .din2           (mem_rdata_wb),
        .sel            (wb_rf_sel_wb),
        .dout           (rf_wdata_wb)
    );

    Exp_Commit  Exp_Commit_inst (
        .priv_vec(priv_vec_wb),
        .exp_code(mcause_global)
    );

    /* Hazard */
    Hazard  Hazard_inst (
        .rf_rd_ls           (inst_ls[11:7]),
        .rf_rd_wb           (inst_wb[11:7]),
        .rf_we_ls           (rf_we_ls),
        .rf_we_wb           (rf_we_wb),
        .rf_rs1_ex          (inst_ex[19:15]),
        .rf_rs2_ex          (inst_ex[24:20]),
        .rf_wdata_tmp_ls    (alu_result_ls),
        .rf_wdata_wb        (rf_wdata_wb),
        .forward1_en        (forward1_en),
        .forward2_en        (forward2_en),
        .forward1_data      (forward1_data),
        .forward2_data      (forward2_data),

        .mem_access_ex      (mem_access_ex),
        .rf_rd_ex           (inst_ex[11:7]),
        .rf_rs1_id          (inst_id[19:15]),
        .rf_rs2_id          (inst_id[24:20]),

        .icache_miss        (icache_miss),
        .dcache_miss        (dcache_miss),

        .jump               (jump),
        .jump_target        (jump_target),
        .priv_vec_ex        (priv_vec_ex),
        .pc_ex              (pc_ex),
        .priv_vec_wb        (priv_vec_wb),
        .pc_wb              (pc_wb),
        .mepc_global        (mepc_global),
        .mtvec_global       (mtvec_global),
        .mcause_global      (mcause_global),

        .pc_set             (pc_set),
        .IF1_IF2_flush      (IF1_IF2_flush),
        .IF2_ID_flush       (IF2_ID_flush),
        .ID_EX_flush        (ID_EX_flush),
        .EX_LS_flush        (EX_LS_flush),
        .LS_WB_flush        (LS_WB_flush),
        .icache_flush       (icache_flush),
        .pc_stall           (pc_stall),
        .IF1_IF2_stall      (IF1_IF2_stall),
        .IF2_ID_stall       (IF2_ID_stall),
        .ID_EX_stall        (ID_EX_stall),
        .EX_LS_stall        (EX_LS_stall),
        .LS_WB_stall        (LS_WB_stall),
        .icache_stall       (icache_stall),
        .pc_set_target      (pc_target)
    ); 

    /* AXI Arbiter */
    axi_arbiter  axi_arbiter_inst (
        .clk                (clk),
        .rstn               (rstn),
        .i_rvalid           (i_rvalid),
        .i_rready           (i_rready),
        .i_raddr            (i_raddr),
        .i_rdata            (i_rdata),
        .i_rlast            (i_rlast),
        .i_rsize            (i_rsize),
        .i_rlen             (i_rlen),
        .d_rvalid           (d_rvalid),
        .d_rready           (d_rready),
        .d_raddr            (d_raddr),
        .d_rdata            (d_rdata),
        .d_rlast            (d_rlast),
        .d_rsize            (d_rsize),
        .d_rlen             (d_rlen),
        .d_wvalid           (d_wvalid),
        .d_wready           (d_wready),
        .d_waddr            (d_waddr),
        .d_wdata            (d_wdata),
        .d_wstrb            (d_wstrb),
        .d_wlast            (d_wlast),
        .d_wsize            (d_wsize),
        .d_wlen             (d_wlen),
        .d_bvalid           (d_bvalid),
        .d_bready           (d_bready),
        .araddr             (araddr),
        .arvalid            (arvalid),
        .arready            (arready),
        .arlen              (arlen),
        .arsize             (arsize),
        .arburst            (arburst),
        .rdata              (rdata),
        .rresp              (rresp),
        .rvalid             (rvalid),
        .rready             (rready),
        .rlast              (rlast),
        .awaddr             (awaddr),
        .awvalid            (awvalid),
        .awready            (awready),
        .awlen              (awlen),
        .awsize             (awsize),
        .awburst            (awburst),
        .wdata              (wdata),
        .wstrb              (wstrb),
        .wvalid             (wvalid),
        .wready             (wready),
        .wlast              (wlast),
        .bresp              (bresp),
        .bvalid             (bvalid),
        .bready             (bready)
    );
`ifdef DEBUG
    assign putchar = |wstrb_ex && (&alu_result_ex);
    assign c = mem_wdata_ex[31 : 24];
`endif
endmodule
