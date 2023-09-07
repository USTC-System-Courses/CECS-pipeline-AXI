`timescale 1ns/1ps
`include "./include/config.sv"
module DCache_Write_Ctrl(
    input  logic [31:0] wdata,
    input  logic [31:0] mem_waddr,
    input  logic [ 4:0] mem_access,
    output logic [ 3:0] wstrb,
    output logic [31:0] mem_wdata
);
    wire is_store           = mem_access[`STORE_BIT];
    wire [2:0] store_type   = mem_access[2:0];

    always_comb begin
        if(is_store) begin
            case(store_type)
            `STORE_B: begin
                wstrb = 4'h1 << mem_waddr[1:0];
                mem_wdata = wdata << {mem_waddr[1:0], 3'b0};
            end
            `STORE_H: begin
                wstrb = 4'h3 << mem_waddr[1:0];
                mem_wdata = wdata << {mem_waddr[1:0], 3'b0};
            end
            `STORE_W: begin
                wstrb = 4'hf;
                mem_wdata = wdata;
            end
            default: begin
                wstrb = 4'h0;
                mem_wdata = 32'h0;
            end
            endcase
        end
        else begin
            wstrb = 4'h0;
            mem_wdata = 32'h0;
        end
    end
endmodule
