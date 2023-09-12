
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Author: Ma Zirui
// Course: Comprehensive Experiment of Computing System
// Module: Data Cache
// 
//////////////////////////////////////////////////////////////////////////////////

module DCache #(
    parameter INDEX_WIDTH       = 4,
    parameter WORD_OFFSET_WIDTH = 2
)(
    input  logic [ 0:0]     clk,
    input  logic [ 0:0]     rstn,
    /* from pipeline */
    input  logic [31:0]     addr,               // read/write address
    // read
    input  logic [ 0:0]     rvalid,             // valid signal of read request from pipeline
    output logic [31:0]     rdata,              // read data to pipeline
    input  logic [ 2:0]     rsize,              // indicate the size of read data once, if rsize = n then read 2^n bytes once
    // write
    input  logic [ 0:0]     wvalid,             // valid signal of write request from pipeline
    input  logic [31:0]     wdata,              // write data from pipeline
    input  logic [ 3:0]     wstrb,              // write mask of each write-back word from pipeline, if the request is a read request, wstrb is 4'b0
    output logic [ 0:0]     dcache_miss,
    // fence.i
    input  logic [ 0:0]     fencei_valid,
    // fence
    input  logic [ 0:0]     fence_valid,

    /* from AXI arbiter */
    // read
    output logic [ 0:0]     d_rvalid,           // valid signal of read request to main memory
    input  logic [ 0:0]     d_rready,           // ready signal of read request from main memory
    output logic [31:0]     d_raddr,            // read address to main memory
    input  logic [31:0]     d_rdata,            // read data from main memory
    input  logic [ 0:0]     d_rlast,            // indicate the last beat of read data from main memory
    output logic [ 2:0]     d_rsize,            // indicate the size of read data once, if d_rsize = n then read 2^n bytes once
    output logic [ 7:0]     d_rlen,             // indicate the number of read data, if d_rlen = n then read n+1 times
    // write
    output logic [ 0:0]     d_wvalid,           // valid signal of write request to main memory
    input  logic [ 0:0]     d_wready,           // ready signal of write request from main memory
    output logic [31:0]     d_waddr,            // write address to main memory
    output logic [31:0]     d_wdata,            // write data to main memory
    output logic [ 3:0]     d_wstrb,            // write mask of each write-back word to main memory
    output logic [ 0:0]     d_wlast,            // indicate the last beat of write data to main memory
    output logic [ 2:0]     d_wsize,            // indicate the size of write data once, if d_wsize = n then write 2^n bytes once
    output logic [ 7:0]     d_wlen,             // indicate the number of write data, if d_wlen = n then write n+1 times

    // back
    input  logic [ 0:0]     d_bvalid,           // valid signal of write back request from main memory
    output logic [ 0:0]     d_bready            // ready signal of write back request to main memory
);
    localparam 
        BYTE_OFFSET_WIDTH   = WORD_OFFSET_WIDTH + 2,                // total offset bits
        TAG_WIDTH           = 32 - BYTE_OFFSET_WIDTH - INDEX_WIDTH, // tag bits
        SET_NUM             = 1 << INDEX_WIDTH,                     // block(set) number of one Road
        WORD_NUM            = 1 << WORD_OFFSET_WIDTH,               // words per block(set)
        BYTE_NUM            = 1 << BYTE_OFFSET_WIDTH,               // bytes per block(set)
        BIT_NUM             = BYTE_NUM << 3;                        // bits per block(set)                     

/* -------------- 0 declare the signal -------------- */
    // request buffer
    logic   [0:0]               req_buf_we;
    logic   [31:0]              wdata_pipe, addr_pipe;
    logic   [3:0]               wstrb_pipe;
    logic   [2:0]               rsize_pipe;
    logic   [0:0]               fence_valid_pipe;
    logic   [0:0]               valid_flush;
    logic   [0:0]               we_pipe;
    logic   [0:0]               rvalid_pipe;
    logic   [0:0]               wvalid_pipe; 

    // return buffer
    logic   [BIT_NUM-1:0]       ret_buf;

    // data memory
    logic   [INDEX_WIDTH-1:0]   r_index, w_index;
    logic   [BYTE_NUM-1:0]      mem_we [2];
    logic   [BIT_NUM-1:0]       mem_rdata [2];
    logic   [BIT_NUM-1:0]       mem_wdata;

    // tag memory
    logic   [1:0]               tagv_we;           
    logic   [TAG_WIDTH-1:0]     w_tag;
    logic   [TAG_WIDTH-1:0]     tag_rdata [2]; 

    // valid memory
    logic   [SET_NUM-1:0]       valid_bit_mem [2];  
    logic   [0:0]               valid_bit_rdata [2];

    // hit
    logic   [1:0]               hit;
    logic                       cache_hit;
    logic   [TAG_WIDTH-1:0]     tag;
    logic                       hit_way;

    // wdata control
    logic   [BIT_NUM-1:0]       wdata_pipe_512;
    logic   [BIT_NUM-1:0]       wstrb_pipe_512;
    logic                       wdata_from_pipe;

    // rdata control
    logic                       data_from_mem;

    // LRU replace
    logic                       lru_sel;
    logic                       lru_hit_update;
    logic                       lru_refill_update;
    logic   [SET_NUM-1:0]       lru;

    // dirty table
    logic                       dirty_info;
    logic                       dirty_refill;
    logic                       dirty_we;
    logic                       dirty_clean_all;
    logic   [SET_NUM-1:0]       dirty_table[2];

    // write back buffer
    logic   [BIT_NUM-1:0]       wbuf;
    logic                       wbuf_we;

    // miss buffer
    logic   [31:0]              maddr_buf;
    logic                       mbuf_we;

    // communication between write fsm and main fsm
    logic                       wfsm_en, wfsm_reset, wrt_finish;

    // a counter for write back
    logic [WORD_OFFSET_WIDTH:0] write_counter;
    logic                       write_counter_reset, write_counter_en;

    // a counter for fence.i read
    logic   [INDEX_WIDTH:0]     addr_cnt;
    logic                       addr_cnt_add;


/* -------------- 1 request buffer : lock the read request addr -------------- */
    // Lab6 TODO: generate uncache signal
    always_ff @(posedge clk) begin
        if(!rstn) begin
            addr_pipe           <= 0;
            wdata_pipe          <= 0;
            wstrb_pipe          <= 0;
            rsize_pipe          <= 0;
            fence_valid_pipe    <= 0;
            valid_flush         <= 0;
            we_pipe             <= 0;
            rvalid_pipe         <= 0;
            wvalid_pipe         <= 0;
        end
        else if(req_buf_we) begin
            addr_pipe           <= addr;
            wdata_pipe          <= wdata;
            wstrb_pipe          <= wstrb;
            rsize_pipe          <= rsize;
            fence_valid_pipe    <= fence_valid || fencei_valid;
            valid_flush         <= fence_valid;
            we_pipe             <= |wstrb;
            rvalid_pipe         <= rvalid;
            wvalid_pipe         <= wvalid;
        end
    end

/*--------------  2 return buffer : cat the return data -------------- */
    always_ff @(posedge clk) begin
        if(!rstn) begin
            ret_buf <= 0;
        end
        else if(d_rvalid && d_rready) begin
            ret_buf <= {d_rdata, ret_buf[BIT_NUM-1:32]};
        end
    end

/* -------------- 3 data memory: store the cached data -------------- */

    /* address of read and write */
    wire read_from_cnt      = fence_valid_pipe || fencei_valid || fence_valid;
    assign r_index          = read_from_cnt ? addr_cnt[INDEX_WIDTH-1:0] : addr[BYTE_OFFSET_WIDTH+INDEX_WIDTH-1:BYTE_OFFSET_WIDTH];
    assign w_index          = read_from_cnt ? addr_cnt[INDEX_WIDTH-1:0] : addr_pipe[BYTE_OFFSET_WIDTH+INDEX_WIDTH-1:BYTE_OFFSET_WIDTH];

    /* 2-way data memory */
    BRAM_bytewrite #(
        .DATA_WIDTH   (BIT_NUM),
        .ADDR_WIDTH   (INDEX_WIDTH)
    )
    data_mem0 (
        .clk      (clk ),
        .raddr    (r_index),
        .waddr    (w_index),
        .din      (mem_wdata),
        .we       (mem_we[0]),
        .dout     (mem_rdata[0])
    );
    BRAM_bytewrite #(
        .DATA_WIDTH   (BIT_NUM),
        .ADDR_WIDTH   (INDEX_WIDTH)
    )
    data_mem1 (
        .clk      (clk ),
        .raddr    (r_index),
        .waddr    (w_index),
        .din      (mem_wdata),
        .we       (mem_we[1]),
        .dout     (mem_rdata[1])
    );

/* -------------- 4 tag memory: store the address tag of the cached data -------------- */
    /* 2-way tagv memory */
    assign w_tag = addr_pipe[31:32-TAG_WIDTH];
    BRAM_common #(
        .DATA_WIDTH (TAG_WIDTH),
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
        .DATA_WIDTH (TAG_WIDTH),
        .ADDR_WIDTH (INDEX_WIDTH)
    ) tag_mem1 (
        .clk      (clk ),
        .raddr    (r_index),
        .waddr    (w_index),
        .din      (w_tag),
        .we       (tagv_we[1]),
        .dout     (tag_rdata[1][TAG_WIDTH-1:0])
    );

/* -------------- 5 valid memory: store the valid bit of the cached data -------------- */
    /* valid memory write */
    always_ff @(posedge clk) begin
        if(!rstn || valid_flush) begin
            valid_bit_mem[0]        <= 0;
        end
        else if(tagv_we[0]) begin
            valid_bit_mem[0][w_index] <= 1;
        end

        if(!rstn || valid_flush) begin
            valid_bit_mem[1]        <= 0;
        end
        else if(tagv_we[1]) begin
            valid_bit_mem[1][w_index] <= 1;
        end
    end
    /* valid memory read */
    always_ff @(posedge clk) begin
        valid_bit_rdata[0] <= valid_bit_mem[0][r_index];
        valid_bit_rdata[1] <= valid_bit_mem[1][r_index];
    end

/* -------------- 6 hit logic: valid and tags is equal -------------- */
    assign tag          = addr_pipe[31:32-TAG_WIDTH];                                  
    assign hit[0]       = valid_bit_rdata[0] && (tag_rdata[0][TAG_WIDTH-1:0] == tag); 
    assign hit[1]       = valid_bit_rdata[1] && (tag_rdata[1][TAG_WIDTH-1:0] == tag);
    assign cache_hit    = |hit;
    assign hit_way      = hit[0] ? 0 : 1;                                              

/* -------------- 7 write data control: shift the wdata and cat wdata with data returned from memory -------------- */
    assign wdata_pipe_512 = {{(BIT_NUM-32){1'b0}}, wdata_pipe} << {addr_pipe[BYTE_OFFSET_WIDTH-1:2], 5'b0};
    assign wstrb_pipe_512 = {
            {(BIT_NUM-32){1'b0}}, 
            ({{8{wstrb_pipe[3]}}, {8{wstrb_pipe[2]}}, {8{wstrb_pipe[1]}}, {8{wstrb_pipe[0]}}})
        } << {addr_pipe[BYTE_OFFSET_WIDTH-1:2], 5'b0};
    always_comb begin
        if(wdata_from_pipe) begin
            mem_wdata = wdata_pipe_512;
        end
        else begin
            mem_wdata = ret_buf & ~wstrb_pipe_512 | wdata_pipe_512 & wstrb_pipe_512;
        end
    end

/* -------------- 8 read data control: choose data from mem or return buffer -------------- */
    wire [BIT_NUM-1:0] rdata_mem, rdata_ret;
    assign rdata_mem    = mem_rdata[hit_way] >> {addr_pipe[BYTE_OFFSET_WIDTH-1:2], 5'b0};
    // Lab6 TODO: generate rdata_ret for uncache
    assign rdata_ret    = ret_buf >> {addr_pipe[BYTE_OFFSET_WIDTH-1:2], 5'b0};
    assign rdata        = data_from_mem ? rdata_mem[31:0] : rdata_ret[31:0];

/* -------------- 9 LRU replace: choose the way to replace -------------- */
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
    /* lru_sel: select the way to replace */
    assign lru_sel = ~lru[w_index];

/* -------------- 10 dirty table: record the dirty information of each set -------------- */
    always_ff @(posedge clk) begin
        if(!rstn || dirty_clean_all) begin
            dirty_table[0] <= 0;
            dirty_table[1] <= 0;
        end
        else if(dirty_refill) begin
            dirty_table[lru_sel][w_index] <= we_pipe;
        end
        else if(dirty_we) begin
            dirty_table[hit_way][w_index] <= 1;
        end
    end
    assign dirty_info = dirty_table[fence_valid_pipe ? addr_cnt[INDEX_WIDTH] : lru_sel][w_index]; 

/* -------------- 11 write back buffer: store the cache line or data to be write back -------------- */

    always_ff @(posedge clk) begin
        if(!rstn) begin
            wbuf <= 0;
        end
        else if(wbuf_we) begin
            if(fence_valid_pipe) begin
                wbuf <= addr_cnt[INDEX_WIDTH] ? mem_rdata[1] : mem_rdata[0];
            end

            // Lab6 TODO：generate wbuf for uncache here

            else begin
                wbuf <= lru_sel ? mem_rdata[1] : mem_rdata[0];
            end
        end
        // shift right to write back 32 bytes
        else if(d_wvalid && d_wready) begin
            wbuf <= {32'b0, wbuf[BIT_NUM-1:32]};
        end
    end

/* -------------- 12 miss address buffer: store the address of the cache line to be write -------------- */
    always_ff @(posedge clk) begin
        if(!rstn) begin
            maddr_buf <= 0;
        end
        else if(mbuf_we) begin
            // Lab6 TODO: generate maddr_buf for uncache here
            maddr_buf <= {
                tag_rdata[fence_valid_pipe ? addr_cnt[INDEX_WIDTH] : lru_sel][TAG_WIDTH-1:0], 
                w_index, {BYTE_OFFSET_WIDTH{1'b0}}
            };
        end
    end

/* -------------- 13 addr_cnt for fence.i -------------- */
    /* addr_cnt for fence.i */
    always_ff @(posedge clk) begin
        if(!rstn) begin
            addr_cnt <= 0;
        end
        else if(addr_cnt_add) begin
            addr_cnt <= addr_cnt + 1;
        end
    end

/* -------------- 14 memory settings -------------- */
    // Lab6 TODO: generate signals for uncache 
    assign d_raddr  = {addr_pipe[31:BYTE_OFFSET_WIDTH], {BYTE_OFFSET_WIDTH{1'b0}}};
    assign d_rsize  = 3'h2;
    assign d_rlen   = WORD_NUM - 1;
    assign d_waddr  = maddr_buf;
    assign d_wsize  = 3'h2;
    assign d_wlen   = WORD_NUM - 1;
    assign d_wdata  = wbuf[31:0];
    assign d_wstrb  = 4'b1111;

/* -------------- 15 main FSM: mainly for read -------------- */
    enum logic [1:0] {IDLE, MISS, REFILL, WAIT_WRITE} state, next_state;
    // stage 1: state register
    always_ff @(posedge clk) begin
        if(!rstn) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    // stage 2: next state logic
    always_comb begin
        case(state)
        IDLE: begin
            if(rvalid_pipe || wvalid_pipe) begin
                // Lab6 TODO：generate next_state for uncache here

                if(cache_hit) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = MISS;
                end
            end
            else if(fence_valid_pipe) begin
                next_state = MISS;
            end
            else begin
                next_state = IDLE;
            end
        end
        MISS: begin
            if(fence_valid_pipe) begin
                next_state = WAIT_WRITE;
            end
            else if(d_rready && d_rlast) begin
                // Lab6 TODO: fix next_state to support uncache here
                next_state = REFILL;
            end
            else begin
                next_state = MISS;
            end
        end
        REFILL: begin
            next_state = WAIT_WRITE;
        end
        WAIT_WRITE: begin
            if(wrt_finish) begin
                if(fence_valid_pipe) begin
                    next_state = addr_cnt == 0 ? IDLE : MISS;
                end
                else begin
                    next_state = IDLE;
                end
            end
            else begin
                next_state = WAIT_WRITE;
            end
        end
        default: begin
            next_state = IDLE;
        end
        endcase
    end
    // stage 3: output
    always_comb begin
        // default
        req_buf_we           = 0;
        wbuf_we              = 0;
        mbuf_we              = 0;
        d_rvalid             = 0;
        wfsm_en              = 0;
        wfsm_reset           = 0;
        mem_we[0]            = 0;
        mem_we[1]            = 0;
        tagv_we[0]           = 0;
        tagv_we[1]           = 0;
        data_from_mem        = 1;
        wdata_from_pipe      = 1;
        lru_hit_update       = 0;
        lru_refill_update    = 0;
        dirty_refill         = 0;
        dirty_we             = 0;
        addr_cnt_add         = 0;
        dcache_miss          = 0;
        dirty_clean_all      = 0;
        case(state)
        IDLE: begin
            if(rvalid_pipe || wvalid_pipe) begin
                // Lab6 TODO: generate output for uncache here

                if(cache_hit) begin
                    mem_we[hit_way]         = {{(BYTE_NUM-4){1'b0}}, wstrb_pipe} << {addr_pipe[BYTE_OFFSET_WIDTH-1:2], 2'b0};
                    req_buf_we              = 1;
                    lru_hit_update          = 1;
                    dirty_we                = we_pipe;
                end
                else begin
                    wbuf_we         = 1;
                    mbuf_we         = 1;
                    wfsm_en         = 1;
                    dcache_miss     = 1;
                end
            end
            else if(fence_valid_pipe) begin
                wbuf_we         = 1;
                mbuf_we         = 1;
                wfsm_en         = 1;
                dcache_miss     = 1;
            end
            else begin
                req_buf_we = 1;
            end
        end
        MISS: begin
            if(fence_valid_pipe) begin
                addr_cnt_add    = 1;
                wbuf_we         = 1;
                mbuf_we         = 1;
                wfsm_en         = 1;
                dcache_miss     = 1;
            end
            else begin
                d_rvalid        = 1;
                dcache_miss     = 1;
            end

        end
        REFILL: begin
            tagv_we[lru_sel]        = 1;
            mem_we[lru_sel]         = -1;
            wdata_from_pipe         = 0;
            lru_refill_update       = 1;
            dirty_refill            = 1;
            dcache_miss             = 1;
        end
        WAIT_WRITE: begin
            wfsm_reset      = 1;
            if(fence_valid_pipe) begin
                dcache_miss         = !(addr_cnt == 0 && wrt_finish);
                dirty_clean_all     = addr_cnt == 0 && wrt_finish;
                req_buf_we          = addr_cnt == 0 && wrt_finish;
            end
            else begin
                dcache_miss     = !wrt_finish;
                data_from_mem   = 0;
                req_buf_we      = wrt_finish;
            end
        end
        default:;
        endcase
    end

/* -------------- 16 write fsm: for write back-------------- */
    enum logic [1:0] {INIT, WRITE, FINISH} wfsm_state, wfsm_next_state;

    // Lab6 TODO: fix write_num generation for uncache here
    logic [WORD_OFFSET_WIDTH:0] write_num =  WORD_NUM - 1;

    /* counter of write back */
    always_ff @(posedge clk) begin
        if(!rstn) begin
            write_counter <= 0;
        end
        else if(write_counter_reset) begin
            write_counter <= 0;
        end
        else if(write_counter_en) begin
            write_counter <=  write_counter + 1;
        end
    end
    // stage 1: state register
    always_ff @(posedge clk) begin
        if(!rstn) begin
            wfsm_state <= INIT;
        end
        else begin
            wfsm_state <= wfsm_next_state;
        end
    end
    // stage 2: next state logic
    always_comb begin
        case(wfsm_state)
        INIT: begin
            if(wfsm_en) begin
                // Lab6 TODO: generate wfsm_next_state for uncache here
                wfsm_next_state = dirty_info ? WRITE : FINISH;
            end
            else begin
                wfsm_next_state = INIT;
            end
        end
        WRITE: begin
            if(d_bvalid) begin
                wfsm_next_state = FINISH;
            end
            else begin
                wfsm_next_state = WRITE;
            end
        end
        FINISH: begin
            if(wfsm_reset) begin
                wfsm_next_state = INIT;
            end
            else begin
                wfsm_next_state = FINISH;
            end
        end
        default: begin
            wfsm_next_state = INIT;
        end
        endcase
    end
    // stage 3: output
    always_comb begin
        wrt_finish          = 0;
        write_counter_reset = 0;
        write_counter_en    = 0;
        d_wvalid            = 0;
        d_wlast             = 0;
        d_bready            = 0;
        case(wfsm_state)
        INIT: begin
            write_counter_reset = 1;
        end
        WRITE: begin
            d_wvalid            = !write_counter[WORD_OFFSET_WIDTH];
            d_wlast             = (write_counter == write_num);
            write_counter_en    = d_wready;
            d_bready            = 1;
        end
        FINISH: begin
            wrt_finish = 1;
        end
        default:;
        endcase
    end

endmodule
