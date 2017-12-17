`timescale 1ns / 1ps
`include "head.v"
module TriggerEn(
    input CLK,
    input EN,
    input [31:0] IN,
    input nRST,
    output reg [31:0] OUT
);
    always@(posedge CLK || negedge nRST) begin
        if (!nRST) begin
            OUT <= 32'b0;
        end else if (EN) begin
            OUT <= IN;
        end
    end
endmodule
