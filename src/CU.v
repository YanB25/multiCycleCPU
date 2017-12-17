`include "head.v"
`timescale 1ns / 1ps
module State (
    input CLK,
    input [5:0] opCode,
    input [5:0] func,
    input nRST,
    output reg [2:0] state
    );
    always@(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            state <= `sIF;
        end else if (state == `sIF) begin
            state <= `sID;
        end else begin
            case (state) 
                `sID : begin
                    case (opCode)
                        `opJ, `opHALT, `opJAL: state <= `sIF;
                        `opJR: begin
                            if (func == `funcJR) begin
                                state <= `sIF;
                            end else begin
                                state <= `sEXE;
                            end
                        end
                        default : state <= `sEXE;
                    endcase
                end
                `sEXE : begin
                    case (opCode)
                        `opBEQ, `opBNE, `opBGTZ : state <= `sIF;
                        `opSW, `opLW : state <= `sMEM;
                        default : state <= `sWB;
                    endcase
                end
                `sMEM : begin
                    case (opCode)
                        `opSW : state <= `sIF;
                        `opLW : state <= `sWB;
                        default : state <= 3'b111; //ERROR!
                    endcase
                end
                `sWB : state <= `sIF;
            endcase
        end
    end
endmodule   


module CU (
    input CLK,
    input [5:0]Op,
    input [5:0]Func,
    input ZERO,
    input SIGN,
    input [3:0] state,
    output ALUScrA,
    output reg ALUScrB,
    output DB,
    output RegWr,
    output nRD,
    output nWR,
    output reg [1:0]RegDst,
    output ExtSel,
    output RegWriteSrc,
    output reg [1:0]PCSel,
    output reg [2:0]ALUop,
    output reg pcWrite,
    output reg IRWrite
    );
    assign ALUScrA = (Op == `opSLL && Func == `funcSLL) ? `FromSA : `FromData;
    // ALUScrB
    always@(*) begin
        case (Op)
            `opADDI, `opORI, `opSW, `opLW, `opSLTI: ALUScrB = `FromImmd;
            default : ALUScrB = `FromData;
        endcase
    end
    // DB
    assign DB = (Op == `opLW) ? `FromDM : `FromALU;
    //RegWr
    assign RegWr = (state == `sWB || Op == `opJAL) ? 1 : 0;
    // nRD
    assign nRD = (Op == `opLW && state == `sMEM) ? 0 : 1;
    // nWR
    assign nWR = (Op == `opSW && state == `sMEM) ? 0: 1;
    // RegDst
    always@(*) begin
        case (Op)
            `opLW, `opADDI, `opORI, `opSLTI : RegDst = `FromRt;
            `opJAL : RegDst = `FromR31;
            default : RegDst = `FromRd;
        endcase
    end
    // ExtSel
    assign ExtSel = (Op == `opORI) ? `ZeroExd : `SignExd;
    // PCSel 
    always@(*) begin
           case (Op) 
            `opBEQ : PCSel = ZERO == 1 ? `RelJmp : `NextIns;
            `opBNE : PCSel = ZERO == 0 ? `RelJmp : `NextIns;
            `opBGTZ : PCSel = (SIGN == 0 && ZERO == 0) ? `RelJmp : `NextIns;
            `opJ, `opJAL: PCSel = `AbsJmp;
            `opJR : PCSel = Func == `funcJR ? `RsJmp : `NextIns;
            default : PCSel =  `NextIns;
        endcase
    end
    
    // ALUop
    always@(*) begin
        case (Op)
            `opRFormat : begin
                case(Func)
                    `funcADD : ALUop = `ALUAdd;
                    `funcSUB : ALUop = `ALUSub;
                    `funcAND : ALUop = `ALUAnd;
                    `funcOR : ALUop = `ALUOr;
                    `funcSLL : ALUop = `ALUSll;
                    `funcSLT : ALUop = `ALUCmps;
                    default : ALUop = `ALUAdd; //maybe bugs
                endcase
            end
            `opORI : ALUop = `ALUOr;
            `opBEQ, `opBNE, `opBGTZ : ALUop = `ALUSub;
            `opSLTI : ALUop = `ALUCmps;
            default : ALUop = `ALUAdd;
        endcase
    end
    // IRWrite
    always@(negedge CLK) begin
        IRWrite = state == `sIF ? 1 : 0;
    end
    // pcWrite
    always@(negedge CLK) begin
        case (Op)
            `opRFormat:
                case(Func):
                    `funcADD, `funcSUB, `funcAND, `funcOR, `funcSLL, `funcSLT:
                        pcWrite = state == `sWB ? 1 : 0;
                    `funcJR:
                        pcWrite = state == `sID ? 1 : 0;
                    default: pcWrite = 0;
                endcase
            `opADDI, `opORI, `opSLTI, `opLW:
                pcWrite = state == `sWB ? 1 : 0;
            `opSW : pcWrite = state == `sMEM ? 1 : 0;
            `opBEQ, `opBNE, `opBGTZ :
                pcWrite = state == `sEXE ? 1 : 0;
            `opJ, `opJAL:
                pcWrite = state == `sID ? 1 : 0;
            default : pcWrite = 0;
        endcase
    end
    //RegWriteSrc
    assign RegWriteSrc = Op == `opJAL ? `FromPCplus4 : `FromDBDR;
endmodule
            


