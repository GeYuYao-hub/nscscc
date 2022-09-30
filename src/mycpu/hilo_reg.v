//////////////////////////////////////////////////////////////////////////////////
// HI/LO�Ĵ���
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module hilo_reg(
    input wire clk,
    input wire rst,
    
    //д�˿�
    input wire we,
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,
    
    //���˿�
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o
);

    // �ڲ�����HILO����������룬����ʵ��д����ģʽ
    reg[`RegBus] hi;
    reg[`RegBus] lo;

    // д�߼�
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            hi <= `ZeroWord;
            lo <= `ZeroWord;
        end else if(we == `WriteEnable) begin
            hi <= hi_i;
            lo <= lo_i;
        end
    end

    // ���߼�
    always @ (*) begin
        if (rst == `RstEnable) begin
            // ��λʱд0
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end else if(we == `WriteEnable) begin
            // д����
            hi_o <= hi_i;
            lo_o <= lo_i;
        end else begin
            hi_o <= hi;
            lo_o <= lo;
        end
    end
endmodule