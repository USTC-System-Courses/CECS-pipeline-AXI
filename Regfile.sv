`timescale 1ns/1ps
module Regfile(
    input  logic [ 0:0] clk,
    input  logic [ 4:0] raddr1,
    input  logic [ 4:0] raddr2,
    input  logic [ 4:0] waddr,
    input  logic [31:0] wdata,
    input  logic        we,
    output logic [31:0] rdata1,
    output logic [31:0] rdata2
`ifdef DEBUG
    ,
    output logic [1023:0] rf_diff
`endif
);
    logic [31:0] rf [31:0];
`ifdef DIFF
    import "DPI-C" function void set_gpr_ptr(input logic [31 : 0] a []);
`endif
    initial begin
`ifdef DIFF
        set_gpr_ptr(rf);
`endif
        for(integer i = 0; i < 32; i++) begin
            rf[i] = 0;
        end
    end
    always_ff @(posedge clk) begin
        if (we) begin
            rf[waddr] <= wdata;
        end
    end

    assign rdata1 = (we && waddr == raddr1) ? wdata : rf[raddr1];
    assign rdata2 = (we && waddr == raddr2) ? wdata : rf[raddr2];
`ifdef DEBUG
    always_comb begin
        rf_diff = {
            rf[31], rf[30], rf[29], rf[28], 
            rf[27], rf[26], rf[25], rf[24], 
            rf[23], rf[22], rf[21], rf[20], 
            rf[19], rf[18], rf[17], rf[16], 
            rf[15], rf[14], rf[13], rf[12], 
            rf[11], rf[10], rf[9], rf[8], 
            rf[7], rf[6], rf[5], rf[4], 
            rf[3], rf[2], rf[1], rf[0]
        };
    end
`endif
endmodule
