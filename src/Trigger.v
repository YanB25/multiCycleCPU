`timescale 1ns / 1ps
`include "head.v"
module Trigger(
    input CLK,
    input [31:0] IN,
    input nRST,
    output reg [31:0] OUT
);
    always@(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            OUT <= 32'b0;
        end else begin
            OUT <= IN;
        end
    end
endmodule
