
//////////////////////////////////////////////////////////////////////////////////
// EX/MEM寄存器
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module ex_mem(
    input wire clk,
    input wire rst,
    input wire flush,

    input wire[5:0] stall,
    
    //来自执行阶段的信息    
    input wire[`RegAddrBus] ex_waddr,
    input wire ex_we,
    input wire[`RegBus] ex_wdata,
    input wire ex_we_hilo, 
    input wire[`RegBus] ex_hi,
    input wire[`RegBus] ex_lo,
    input wire ex_cp0_we,
    input wire[7:0] ex_cp0_waddr,
    input wire[`RegBus] ex_cp0_wdata,
    input wire[`RegBus] ex_pc,
    input wire[31:0] ex_exceptions,
    input wire ex_is_in_delayslot,
    // 访存
    input wire[`AluOpBus] ex_aluop,
    input wire[`RegBus] ex_mem_addr,
    input wire[`RegBus] ex_reg2,
    
    //送到访存阶段的信息
    output reg[`RegAddrBus] mem_waddr,
    output reg mem_we,
    output reg[`RegBus] mem_wdata,
    output reg mem_we_hilo,
    output reg[`RegBus] mem_hi,
    output reg[`RegBus] mem_lo,
    output reg mem_cp0_we,
    output reg[7:0] mem_cp0_waddr,
    output reg[`RegBus] mem_cp0_wdata,
    output reg[`RegBus] mem_pc,
    output reg[31:0] mem_exceptions,
    output reg mem_is_in_delayslot,
    // 访存
    output reg[`AluOpBus] mem_aluop,
    output reg[`RegBus] mem_mem_addr,
    output reg[`RegBus] mem_reg2
    );

    always @ (posedge clk) begin
        if(rst == `RstEnable || flush) begin
            mem_waddr <= `NOPRegAddr;
            mem_we <= `WriteDisable;
            mem_wdata <= `ZeroWord;
            mem_we_hilo <= `WriteDisable;
            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;   
            mem_aluop <= `ALU_OP_NOP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
            mem_cp0_we <= `WriteDisable;
            mem_cp0_waddr <= 8'b00000000;
            mem_cp0_wdata <= `ZeroWord;
            mem_pc <= `ZeroWord;
            mem_exceptions <= `ZeroWord;
            mem_is_in_delayslot <= `False_v;
        end else if (stall[3] == `Stop && stall[4] == `NoStop) begin
            // 处于EX和MEM的暂停交界处，NOP
            mem_waddr <= `NOPRegAddr;
            mem_we <= `WriteDisable;
            mem_wdata <= `ZeroWord;
            mem_we_hilo <= `WriteDisable;
            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;  
            mem_aluop <= `ALU_OP_NOP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord; 
            mem_cp0_we <= `WriteDisable;
            mem_cp0_waddr <= 8'b00000000;
            mem_cp0_wdata <= `ZeroWord;
            mem_pc <= `ZeroWord;
            mem_exceptions <= `ZeroWord;
            mem_is_in_delayslot <= `False_v;
        end else if (stall[3] == `NoStop) begin
            mem_waddr <= ex_waddr;
            mem_we <= ex_we;
            mem_wdata <= ex_wdata;
            mem_we_hilo <= ex_we_hilo;
            mem_hi <= ex_hi;
            mem_lo <= ex_lo; 
            mem_aluop <= ex_aluop;
            mem_mem_addr <= ex_mem_addr;
            mem_reg2 <= ex_reg2;
            mem_cp0_we <= ex_cp0_we;
            mem_cp0_waddr <= ex_cp0_waddr;
            mem_cp0_wdata <= ex_cp0_wdata;
            mem_pc <= ex_pc;
            mem_exceptions <= ex_exceptions;
            mem_is_in_delayslot <= ex_is_in_delayslot;
        end else begin
        end
    end

endmodule
