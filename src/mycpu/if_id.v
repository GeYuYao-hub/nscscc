
//////////////////////////////////////////////////////////////////////////////////
// IF/ID�Ĵ���
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module if_id(
    input wire clk,
    input wire rst,

    input wire flush,

    input wire[5:0] stall,
    
    input wire[`RegBus] if_pc,
    input wire[`RegBus] if_inst,
    input wire[`RegBus] if_exceptions,
    output reg[`RegBus] id_pc,
    output reg[`RegBus] id_inst,  
    output reg[`RegBus] id_exceptions
    );

    always @ (posedge clk) begin
        if (rst == `RstEnable || flush) begin
            // ��λ���쳣ʱ���´�0��NOP
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
            id_exceptions <= `ZeroWord;
        end else if (stall[1] == `Stop && stall[2] == `NoStop) begin
            // IF��ͣ�˶�IDû��ͣ������NOP
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
            id_exceptions <= `ZeroWord;
        end else if (stall[1] == `NoStop) begin
            // ����ʱ����IF������
            id_pc <= if_pc;
            // ��IF�׶����쳣����ֱ�����´�NOP
            id_inst <= (if_exceptions != `ZeroWord || if_pc == `ZeroWord) ? `ZeroWord : if_inst;
            id_exceptions <= if_exceptions;
        end else begin
            // ������������ڱ���ͣ�Ľ��紦����ԭ�ⲻ������������Ĵ�������
        end
    end

endmodule
