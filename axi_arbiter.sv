`timescale 1ns/1ps
module axi_arbiter(
    input  logic [ 0:0] clk,
    input  logic [ 0:0] rstn,

    // from icache
    input  logic [ 0:0] i_rvalid,
    output logic [ 0:0] i_rready,
    input  logic [31:0] i_raddr,
    output logic [31:0] i_rdata,
    output logic [ 0:0] i_rlast,
    input  logic [ 2:0] i_rsize,
    input  logic [ 7:0] i_rlen,

    // from dcache
    input  logic [ 0:0] d_rvalid,
    output logic [ 0:0] d_rready,
    input  logic [31:0] d_raddr,
    output logic [31:0] d_rdata,
    output logic [ 0:0] d_rlast,
    input  logic [ 2:0] d_rsize,
    input  logic [ 7:0] d_rlen,

    input  logic [ 0:0] d_wvalid,
    output logic [ 0:0] d_wready,
    input  logic [31:0] d_waddr,
    input  logic [31:0] d_wdata,
    input  logic [ 3:0] d_wstrb,
    input  logic [ 0:0] d_wlast,
    input  logic [ 2:0] d_wsize,
    input  logic [ 7:0] d_wlen,

    output logic [ 0:0] d_bvalid,
    input  logic [ 0:0] d_bready,
    // from AXI 
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
    output logic [ 0:0] bready
);
    // Lab5 TODO: implement read FSM here
    enum logic [2:0] {R_IDLE, I_AR, I_R, D_AR, D_R} r_crt, r_nxt;
    always @(posedge clk) begin
        if(!rstn) begin
            r_crt <= R_IDLE;
        end else begin
            r_crt <= r_nxt;
        end
    end
    // stage 2: next state logic
    always @(*) begin
        case(r_crt)
        R_IDLE: begin
            // TODO
        end
        I_AR: begin
            // TODO
        end
        I_R: begin
            // TODO
        end
        D_AR: begin
            // TODO
        end
        D_R: begin
            // TODO
        end
        default :                   r_nxt = R_IDLE;    
        endcase
    end
    
    assign i_rdata = rdata;
    assign d_rdata = rdata;
    assign arburst = 2'b01;
    // stage 3: output logic
    always @(*) begin
        i_rready    = 0;
        i_rlast     = 0;
        d_rready    = 0;
        d_rlast     = 0;
        arlen       = 0;
        arsize      = 0;
        arvalid     = 0;
        araddr      = 0;
        rready      = 0;
        case(r_crt) 
        I_AR: begin
            // TODO
        end
        I_R: begin
            // TODO
        end
        D_AR: begin
            // TODO
        end
        D_R: begin
            // TODO
        end
        default:;
        endcase
    end

    // Lab5 TODO: implement write FSM here
    enum logic [1:0] {W_IDLE, D_AW, D_W, D_B} w_crt, w_nxt;
    always @(posedge clk) begin
        if(!rstn) begin
            w_crt <= W_IDLE;
        end else begin
            w_crt <= w_nxt;
        end
    end
    always @(*) begin
        case(w_crt)
        W_IDLE: begin
            // TODO
        end
        D_AW: begin
            // TODO
        end
        D_W: begin
            // TODO
        end
        D_B: begin
            // TODO
        end
        default :                   w_nxt = W_IDLE;    
        endcase
    end
    assign awaddr   = d_waddr;
    assign awlen    = d_wlen;
    assign awsize   = d_wsize;
    assign awburst  = 2'b01;
    assign wdata    = d_wdata;
    assign wstrb    = d_wstrb;

    always @(*) begin
        d_wready    = 0;
        d_bvalid    = 0;
        bready      = 0;
        awvalid     = 0;
        wvalid      = 0;
        wlast       = 0;

        case(w_crt)
        D_AW: begin
            // TODO
        end
        D_W: begin
            // TODO
        end
        D_B: begin
            // TODO
        end
        default:;
        endcase
    end


endmodule
