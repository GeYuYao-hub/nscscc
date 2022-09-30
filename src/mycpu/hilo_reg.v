//////////////////////////////////////////////////////////////////////////////////
// HI/LO寄存器
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module hilo_reg(
    input wire clk,
    input wire rst,
    
    //写端口
    input wire we,
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,
    
    //读端口
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o
);

    // 内部保存HILO，与输出分离，可以实现写优先模式
    reg[`RegBus] hi;
    reg[`RegBus] lo;

    // 写逻辑
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            hi <= `ZeroWord;
            lo <= `ZeroWord;
        end else if(we == `WriteEnable) begin
            hi <= hi_i;
            lo <= lo_i;
        end
    end

    // 读逻辑
    always @ (*) begin
        if (rst == `RstEnable) begin
            // 复位时写0
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end else if(we == `WriteEnable) begin
            // 写优先
            hi_o <= hi_i;
            lo_o <= lo_i;
        end else begin
            hi_o <= hi;
            lo_o <= lo;
        end
    end
endmodule