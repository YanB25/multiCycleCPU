`timescale 1ns/1ps
module CPU_TB;
    reg CLK;
    reg RST;
    initial begin
        CLK = 0;
        RST = 1;
        #1;
        RST = 0;
        #1;
        RST = 1;
    end

    always begin
        #5;
        CLK = ~CLK;
    end
    CPU cpu(
        .clk(CLK),
        .RST(RST)
    );
endmodule