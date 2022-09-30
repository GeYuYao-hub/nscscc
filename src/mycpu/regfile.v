
//////////////////////////////////////////////////////////////////////////////////
// 寄存器堆
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module regfile(
    input wire clk,
    input wire rst,

    input wire we,
    input wire[`RegAddrBus] waddr,
    input wire[`RegBus] wdata,

    input wire re1,
    input wire[`RegAddrBus] raddr1,
    output reg[`RegBus] rdata1,
    
    input wire re2,
    input wire[`RegAddrBus] raddr2,
    output reg[`RegBus] rdata2
    );

    // 定义一个寄存器堆
    reg[`RegBus] regs[0:`RegNum-1];

    // 上升沿时写数据
    always @ (posedge clk) begin
        if (rst == `RstDisable) begin
            // 非复位状态，复位不影响写操作，复位也不置位寄存器堆
            if((we == `WriteEnable) && (waddr != `RegAddrBusWidth'h0)) begin
                // 写使能有效且目标寄存器不为0
                regs[waddr] <= wdata;
            end
        end
    end
    
    // 读端口1，使用 always @ (*)即表明读操作是组合逻辑电路。
    // 写操作是时序逻辑电路，需要明确触发条件
    always @ (*) begin
        if(rst == `RstEnable) begin
            // 复位时写零
            rdata1 <= `ZeroWord;
        end else if(raddr1 == `RegAddrBusWidth'h0) begin
            // 读0时直接返回0
            rdata1 <= `ZeroWord;
        end else if(raddr1 == waddr && we == `WriteEnable && re1 == `ReadEnable) begin
            // 读写同一个寄存器，直接返回写入的数据
            rdata1 <= wdata;
        end else if(re1 == `ReadEnable) begin
            // 允许读则返回内容
            rdata1 <= regs[raddr1];
        end else begin
            // 否则返回0
            rdata1 <= `ZeroWord;
        end
    end

    // 同上，这里是处理读端口2
    always @ (*) begin
        if(rst == `RstEnable) begin
            rdata2 <= `ZeroWord;
        end else if(raddr2 == `RegAddrBusWidth'h0) begin
            rdata2 <= `ZeroWord;
        end else if(raddr2 == waddr && we == `WriteEnable && re2 == `ReadEnable) begin
            rdata2 <= wdata;
        end else if(re2 == `ReadEnable) begin
            rdata2 <= regs[raddr2];
        end else begin
            rdata2 <= `ZeroWord;
        end
    end

endmodule
