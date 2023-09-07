
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Author: Ma Zirui
// Course: Comprehensive Experiment of Computing System
// Module: Instruction Cache
// 
//////////////////////////////////////////////////////////////////////////////////


module ICache #(
    parameter INDEX_WIDTH       = 4,
    parameter WORD_OFFSET_WIDTH = 2
)(
    input  logic [ 0:0] clk,            
    input  logic [ 0:0] rstn,           
    // for pipeline 
    input  logic [ 0:0] rvalid,         // valid signal of read request from pipeline
    input  logic [31:0] raddr,          // read address from pipeline
    output logic [31:0] rdata,          // read data to pipeline
    input  logic [ 0:0] fencei_valid,   // valid signal of fence instruction
    input  logic [ 0:0] fence_valid,    // valid signal of fence instruction
    input  logic [ 0:0] flush,          // flush signal from pipeline
    input  logic [ 0:0] stall,          // stall signal from pipeline
    output logic [ 0:0] icache_miss,   // stall signal to pipeline
    // for AXI arbiter
    output logic [ 0:0] i_rvalid,       // valid signal of read request to main memory
    input  logic [ 0:0] i_rready,       // ready signal of read request from main memory
    output logic [31:0] i_raddr,        // read address to main memory
    input  logic [31:0] i_rdata,        // read data from main memory
    input  logic [ 0:0] i_rlast,        // indicate the last beat of read data from main memory
    output logic [ 2:0] i_rsize,        // indicate the size of read data once, if i_rsize = n then read 2^n bytes once
    output logic [ 7:0] i_rlen          // indicate the number of read data, if i_rlen = n then read n+1 times
);
    localparam 
        BYTE_OFFSET_WIDTH   = WORD_OFFSET_WIDTH + 2,                // total offset bits
        TAG_WIDTH           = 32 - BYTE_OFFSET_WIDTH - INDEX_WIDTH, // tag bits
        SET_NUM             = 1 << INDEX_WIDTH,                     // block(set) number of one Road
        WORD_NUM            = 1 << WORD_OFFSET_WIDTH,               // words per block(set)
        BYTE_NUM            = 1 << BYTE_OFFSET_WIDTH,               // bytes per block(set)
        BIT_NUM             = BYTE_NUM << 3;                        // bits per block(set)

/* -------------- 0 global signal -------------- */
    // request buffer
    logic   [31:0]              addr_pipe;
    logic                       rvalid_pipe;
    logic                       req_buf_we;
    
    // return buffer
    logic   [BIT_NUM-1:0]       ret_buf;

    // data memory
    logic   [INDEX_WIDTH-1:0]   r_index, w_index;                       
    logic   [1:0]               mem_we;                
    logic   [BIT_NUM-1:0]       mem_rdata [0:1];     

    // tagv memory
    logic   [1:0]               tagv_we;          
    logic   [TAG_WIDTH-1:0]     w_tag;
    logic   [TAG_WIDTH:0]       tag_rdata [2]; 
    logic   [SET_NUM-1:0]       valid_bit_mem[2];                       

    // hit
    logic   [1:0]               hit;
    logic                       hit_way;
    logic                       cache_hit;
    logic   [TAG_WIDTH-1:0]     tag;

    // LRU
    logic                       lru_sel;
    logic                       lru_hit_update;
    logic                       lru_refill_update;

    // read control
    logic                       data_from_mem;

    // flush and stall 
    logic                       flush_buf;

/* -------------- 1 request buffer: lock the read request addr -------------- */
    always_ff @(posedge clk) begin
        if(!rstn) begin
            addr_pipe   <= 0;
            rvalid_pipe <= 0;
        end
        else if(req_buf_we) begin
            addr_pipe   <= raddr;
            rvalid_pipe <= rvalid;
        end
    end

/* -------------- 2 return buffer: cat the return 32-bit data and keep the stall data -------------- */
    always_ff @(posedge clk) begin
        if(!rstn) begin
            ret_buf <= 0;
        end
        else if(i_rvalid && i_rready) begin
            ret_buf <= {i_rdata, ret_buf[BIT_NUM-1:32]};
        end
    end
/* -------------- 3 flush buffer: catch the flush signal -------------- */
    always_ff @(posedge clk) begin
        if(!rstn) begin
            flush_buf <= 0;
        end
        else if(flush) begin
            flush_buf <= 1;
        end
        else if(req_buf_we) begin
            flush_buf <= 0;
        end
    end
/* -------------- 4 data memory: store the cached data -------------- */
    /* 2-way data memory */
    // read index
    assign r_index = icache_miss || stall ? 
                     addr_pipe[BYTE_OFFSET_WIDTH+INDEX_WIDTH-1:BYTE_OFFSET_WIDTH] : raddr[BYTE_OFFSET_WIDTH+INDEX_WIDTH-1:BYTE_OFFSET_WIDTH];
    // write index 
    assign w_index = addr_pipe[BYTE_OFFSET_WIDTH+INDEX_WIDTH-1:BYTE_OFFSET_WIDTH];

    BRAM_common #(
        .DATA_WIDTH(BIT_NUM),
        .ADDR_WIDTH (INDEX_WIDTH)
    ) data_mem0 (
        .clk      (clk ),
        .raddr    (r_index),
        .waddr    (w_index),
        .din      (ret_buf),
        .we       (mem_we[0]),
        .dout     (mem_rdata[0])
    );
    BRAM_common #(
        .DATA_WIDTH(BIT_NUM),
        .ADDR_WIDTH (INDEX_WIDTH)
    ) data_mem1 (
        .clk      (clk ),
        .raddr    (r_index),
        .waddr    (w_index),
        .din      (ret_buf),
        .we       (mem_we[1]),
        .dout     (mem_rdata[1])
    );

/* -------------- 5 tag memory: store the address tag of the cached data -------------- */
    // the tag ready to be written to tagv table
    assign w_tag = addr_pipe[31:32-TAG_WIDTH];
    BRAM_common #(
        .DATA_WIDTH(TAG_WIDTH),
        .ADDR_WIDTH (INDEX_WIDTH)
    ) tag_mem0 (
        .clk      (clk ),
        .raddr    (r_index),
        .waddr    (w_index),
        .din      (w_tag),
        .we       (tagv_we[0]),
        .dout     (tag_rdata[0][TAG_WIDTH-1:0])
    );
    BRAM_common #(
        .DATA_WIDTH(TAG_WIDTH),
        .ADDR_WIDTH (INDEX_WIDTH)
    ) tag_mem1 (
        .clk      (clk ),
        .raddr    (r_index),
        .waddr    (w_index),
        .din      (w_tag),
        .we       (tagv_we[1]),
        .dout     (tag_rdata[1][TAG_WIDTH-1:0])
    );

/* -------------- 6 valid memory: store the valid signal of the cached data -------------- */
    /* valid memory */
    always_ff @(posedge clk) begin
        if(!rstn || fence_valid || fencei_valid) begin
            valid_bit_mem[0]        <= 0;
        end
        else if(tagv_we[0]) begin
            valid_bit_mem[0][w_index] <= 1;
        end
        if(!rstn || fence_valid || fencei_valid) begin
            valid_bit_mem[1]        <= 0;
        end
        else if(tagv_we[1]) begin
            valid_bit_mem[1][w_index] <= 1;
        end
    end
    always_ff @(posedge clk) begin
        tag_rdata[0][TAG_WIDTH] <= w_index == r_index ? 1 : valid_bit_mem[0][r_index];
        tag_rdata[1][TAG_WIDTH] <= w_index == r_index ? 1 : valid_bit_mem[1][r_index];
    end
    
/* -------------- 7 hit logic: valid and tags is equal -------------- */
    /* hit */
    assign tag          = addr_pipe[31:32-TAG_WIDTH]; 
    assign hit[0]       = tag_rdata[0][TAG_WIDTH] && (tag_rdata[0][TAG_WIDTH-1:0] == tag); 
    assign hit[1]       = tag_rdata[1][TAG_WIDTH] && (tag_rdata[1][TAG_WIDTH-1:0] == tag);
    assign hit_way      = hit[0] ? 0 : 1;           
    assign cache_hit    = |hit;

/* -------------- 8 read data control: choose data from mem or stall buffer -------------- */
    logic [BIT_NUM-1:0] rdata_mem, rdata_ret;
    assign rdata_mem    = mem_rdata[hit_way] >> {addr_pipe[BYTE_OFFSET_WIDTH-1:2], 5'b0};
    assign rdata_ret    = ret_buf >> {addr_pipe[BYTE_OFFSET_WIDTH-1:2], 5'b0};
    assign rdata        = flush || flush_buf ? 'h13 : (data_from_mem ? rdata_mem[31:0] : rdata_ret[31:0]);

/* -------------- 9 LRU replace: choose the way to replace -------------- */
    reg [SET_NUM-1:0] lru;
    always_ff @(posedge clk) begin
        if(!rstn) begin
            lru <= 0;
        end
        else if(lru_hit_update) begin
            lru[w_index] <= hit_way;
        end
        else if(lru_refill_update) begin
            lru[w_index] <= ~lru[w_index];
        end
    end
    assign lru_sel = ~lru[w_index];

/* -------------- 10 memory settings -------------- */
    assign i_rlen   = WORD_NUM-1;                                                   
    assign i_rsize  = 3'h2;                                                         
    assign i_raddr  = {addr_pipe[31:BYTE_OFFSET_WIDTH], {BYTE_OFFSET_WIDTH{1'b0}}};  

/* -------------- 11 main FSM -------------- */
    /* main FSM */
    enum logic [1:0] {IDLE, MISS, REFILL} state, next_state;
    // stage 1: state transition
    always_ff @(posedge clk) begin
        if(!rstn) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    // stage 2: state transition logic
    always_comb begin
        case(state)
            IDLE: begin
                if(rvalid_pipe)         next_state = cache_hit ? IDLE : MISS;
                else                    next_state = IDLE;
            end
            MISS: begin
                if(i_rready && i_rlast) next_state = REFILL;
                else                    next_state = MISS;
            end
            REFILL:                     next_state = IDLE;
            default:                    next_state = IDLE;
        endcase
    end
    // stage 3: output
    always_comb begin
        req_buf_we              = 0;
        i_rvalid                = 0;
        tagv_we                 = 0;
        mem_we                  = 0;
        data_from_mem           = 1;
        lru_hit_update          = 0;
        lru_refill_update       = 0;
        icache_miss             = 0;
        case(state)
        IDLE: begin
            if(rvalid_pipe) begin
                if(!cache_hit) begin
                    icache_miss     = 1;
                end
                else if(!stall) begin
                    lru_hit_update  = 1;
                    req_buf_we      = 1;
                end
            end
            else begin
                req_buf_we          = 1;
            end
        end
        MISS: begin
            i_rvalid                = 1;
            icache_miss             = 1;
        end
        REFILL: begin
            tagv_we                 = lru_sel ? 1 : 2;
            mem_we                  = lru_sel ? 1 : 2;
            data_from_mem           = 0;
            lru_refill_update       = 1;
            req_buf_we              = !stall;
        end
        default:;
        endcase
    end

endmodule
