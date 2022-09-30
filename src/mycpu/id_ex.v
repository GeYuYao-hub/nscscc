//////////////////////////////////////////////////////////////////////////////////
// ID/EX寄存器
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module id_ex(
    input wire clk,
    input wire rst,
    input wire flush,

    input wire[5:0] stall,
    
    //从译码阶段传递的信息
    input wire[`AluOpBus] id_aluop,
    input wire[`AluSelBus] id_alusel,
    input wire[`RegBus] id_reg1,
    input wire[`RegBus] id_reg2,
    input wire[`RegAddrBus] id_waddr,
    input wire id_we,
    input wire id_is_in_delayslot,
    input wire[`RegBus] id_link_address,
    input wire next_inst_in_delayslot_i,
    input wire next_inst_is_nullified_i,
    input wire[`RegBus] id_inst,
    input wire[`RegBus] id_pc,
    input wire[31:0] id_exceptions,
    
    //传递到执行阶段的信息
    output reg[`AluOpBus] ex_aluop,
    output reg[`AluSelBus] ex_alusel,
    output reg[`RegBus] ex_reg1,
    output reg[`RegBus] ex_reg2,
    output reg[`RegAddrBus] ex_waddr,
    output reg ex_we,
    output reg ex_is_in_delayslot,
    output reg[`RegBus] ex_link_address,
    output reg is_in_delayslot_o,
    output reg is_nullified_o,
    output reg[`RegBus] ex_inst,
    output reg[`RegBus] ex_pc,
    output reg[31:0] ex_exceptions
    );

    always @ (posedge clk) begin
        if (rst == `RstEnable || flush) begin
            ex_aluop <= `ALU_OP_NOP;
            ex_alusel <= `ALU_SEL_NOP;
            ex_reg1 <= `ZeroWord;
            ex_reg2 <= `ZeroWord;
            ex_waddr <= `NOPRegAddr;
            ex_we <= `WriteDisable;
            ex_is_in_delayslot <= `False_v;
            ex_link_address <= `ZeroWord;
            is_in_delayslot_o <= `False_v;
            is_nullified_o <= `False_v;
            ex_inst <= `ZeroWord;
            ex_pc <= `ZeroWord;
            ex_exceptions <= `ZeroWord;
        end else if (stall[2] == `Stop && stall[3] == `NoStop) begin
            // ID暂停而EX没有暂停，输出NOP状态
            ex_aluop <= `ALU_OP_NOP;
            ex_alusel <= `ALU_SEL_NOP;
            ex_reg1 <= `ZeroWord;
            ex_reg2 <= `ZeroWord;
            ex_waddr <= `NOPRegAddr;
            ex_we <= `WriteDisable;
            ex_is_in_delayslot <= `False_v;
            ex_link_address <= `ZeroWord;
            ex_inst <= `ZeroWord;
            ex_pc <= `ZeroWord;
            ex_exceptions <= `ZeroWord;
            // ID当前指令是否在延迟槽中状态不变
        end else if (stall[2] == `NoStop) begin        
            ex_aluop <= id_aluop;
            ex_alusel <= id_alusel;
            ex_reg1 <= id_reg1;
            ex_reg2 <= id_reg2;
            ex_waddr <= id_waddr;
            ex_we <= id_we;
            ex_is_in_delayslot <= id_is_in_delayslot;
            ex_link_address <= id_link_address;
            is_in_delayslot_o <= next_inst_in_delayslot_i;
            is_nullified_o <= next_inst_is_nullified_i;
            ex_inst <= id_inst;
            ex_pc <= id_pc;
            ex_exceptions <= id_exceptions;
        end else begin
        end
    end
endmodule
