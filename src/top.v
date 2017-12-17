`include "head.v"
`timescale 1ns / 1ps
module CPU (
    input clk,
    input RST
    );
    wire [3:0] pos_ctrl;
    wire [7:0] num_ctrl;
    wire [31:0] pc;
    wire [31:0] newpc;
    wire [15:0] immd16;
    wire [25:0] immd26;
    wire [1:0]PCSel;
    PC pcinstance(
        .clk(clk),
        .RST(RST),
        .newpc(newpc),
        .pc(pc)
    );

    PCHelper pchelper(
        .pc(pc),
        .immd16(immd16),
        .immd26(immd26),
        .sel(PCSel),
        .newpc(newpc)
    );
    wire [31:0] ins;
    wire romnrd = 0;
    ROM rom(
        .nrd(romnrd),
        .addr(pc),
        .dataOut(ins)
    );
    wire [31:0] IROUT;
    TriggerEn IR(
        .CLK(clk),
        .nRST(RST),
        .EN(IRWrite), 
        .IN(ins),
        .OUT(IROUT)
    );

    wire [5:0] op;
    wire [5:0] func;
    wire [4:0] rs;
    wire [4:0] rt;
    wire [4:0] rd;
    wire [4:0] sftamt;
    Decoder decoder(
        .ins(IROUT),
        .op(op),
        .func(func),
        .rs(rs),
        .rt(rt),
        .rd(rd),
        .immd16(immd16),
        .immd26(immd26),
        .sftamt(sftamt)
    );

    wire ZERO;
    wire SIGN;
    wire ALUScrA;
    wire ALUScrB;
    wire DB;
    wire RegWr;
    wire nRD;
    wire nWR;
    wire [1:0]RegDst;
    wire ExtSel;
    wire [2:0]ALUop;
    wire RegWriteSrc;
    wire IRWrite;
    CU cu(
        .Op(op),
        .Func(func),
        .ZERO(ZERO),
        .SIGN(SIGN),
        .ALUScrA(ALUScrA),
        .ALUScrB(ALUScrB),
        .DB(DB),
        .RegWr(RegWr),
        .nRD(nRD),
        .nWR(nWR),
        .RegDst(RegDst),
        .ExtSel(ExtSel),
        .PCSel(PCSel),
        .ALUop(ALUop),
        .RegWriteSrc(RegWriteSrc),
        .IRWrite(IRWrite)
    );

    wire [31:0] ReadData1;
    wire [31:0] ReadData2;
    wire [4:0] WriteReg;
    assign WriteReg = RegDst == `FromRt ? rt : rd;
    case (RegDst)
        `FromRT : WriteReg = rt;
        `FromRd : WriteReg = rd;
        `FromR31 : WriteReg = 5'b11111;
        default : WriteReg = 5'b0; // ERROR!
    end
    wire [31:0] RegWriteData;
    wire [31:0] ALUResult;
    wire [31:0] RAMOut;
    wire [31:0] DBDRIn;
    assign DBDRIn = DB == `FromALU ? ALUResult : RAMOut;
    Trigger DBDR(
        .CLK(clk),
        .nRST(RST),
        .IN(DBDRIn),
        .OUT(DBDROut)
    );
    RegWriteData = RegWriteSrc == `FromDBDR ? DBDROut : pc + 4; 
    RegFile regfile(
        .CLK(clk),
        .RST(RST),
        .RegWre(RegWr),
        .ReadReg1(rs),
        .ReadReg2(rt),
        .WriteReg(WriteReg),
        .WriteData(RegWriteData),
        .ReadData1(ReadData1),
        .ReadData2(ReadData2)
    );
    wire [31:0] ADROut;
    Trigger ADR (
        .CLK(clk),
        .nRST(RST),
        .IN(ReadData1),
        .OUT(ADROut)
    );
    wire [31:0] BDROut;
    Trigger BDR (
        .CLK(clk),
        .nRST(RST),
        .IN(ReadData2),
        .OUT(BDROut)
    );


    wire [31:0] exd_immd;
    Extend extend(
        .immd16(immd16),
        .extSel(ExtSel),
        .exd_immd(exd_immd)
    );

    wire [31:0] ALUa;
    wire [31:0] zexd_sftamt;
    assign zexd_sftamt = {{27{1'b0}}, sftamt}; 
    assign ALUa = ALUScrA == `FromData ? ADROut : zexd_sftamt;
    wire [31:0] ALUb;
    assign ALUb = ALUScrB == `FromData ? BDROut : exd_immd;
    ALU32 alu32(
        .ALUopcode(ALUop),
        .rega(ALUa),
        .regb(ALUb),
        .result(ALUResult),
        .zero(ZERO),
        .sign(SIGN)
    );
    wire [31:0] ALUDROut;
    Trigger ALUoutDR(
        .CLK(clk),
        .nRST(RST),
        .IN(ALUResult),
        .OUT(ALUDROut)
    );
    RAM ram(
        .clk(clk),
        .address(ALUDROut),
        .writeData(BDROut),
        .nRD(nRD),
        .nWR(nWR),
        .Dataout(RAMOut)
    );
endmodule
