`timescale 1ns/1ps
`include "./include/config.sv"
module DCache_Read_Ctrl(
    input  logic [31:0] mem_rdata,
    input  logic [31:0] mem_raddr,
    input  logic [ 4:0] mem_access,
    output logic [31:0] rdata
);
    wire [2:0] load_type    = mem_access[2:0];
    wire [31:0] load_data   = mem_rdata >> {mem_raddr[1:0], 3'b0};

    always_comb begin
        case(load_type)
        `LOAD_B: begin
            rdata = {{24{load_data[7]}}, load_data[7:0]};
        end
        `LOAD_H: begin
            rdata = {{16{load_data[15]}}, load_data[15:0]};
        end
        `LOAD_W: begin
            rdata = load_data;
        end
        `LOAD_UB: begin
            rdata = {24'h0, load_data[7:0]};
        end
        `LOAD_UH: begin
            rdata = {16'h0, load_data[15:0]};
        end
        default: begin
            rdata = 32'h0;
        end
        endcase
    end
endmodule
