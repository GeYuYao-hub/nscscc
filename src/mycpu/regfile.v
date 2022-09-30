
//////////////////////////////////////////////////////////////////////////////////
// �Ĵ�����
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

    // ����һ���Ĵ�����
    reg[`RegBus] regs[0:`RegNum-1];

    // ������ʱд����
    always @ (posedge clk) begin
        if (rst == `RstDisable) begin
            // �Ǹ�λ״̬����λ��Ӱ��д��������λҲ����λ�Ĵ�����
            if((we == `WriteEnable) && (waddr != `RegAddrBusWidth'h0)) begin
                // дʹ����Ч��Ŀ��Ĵ�����Ϊ0
                regs[waddr] <= wdata;
            end
        end
    end
    
    // ���˿�1��ʹ�� always @ (*)������������������߼���·��
    // д������ʱ���߼���·����Ҫ��ȷ��������
    always @ (*) begin
        if(rst == `RstEnable) begin
            // ��λʱд��
            rdata1 <= `ZeroWord;
        end else if(raddr1 == `RegAddrBusWidth'h0) begin
            // ��0ʱֱ�ӷ���0
            rdata1 <= `ZeroWord;
        end else if(raddr1 == waddr && we == `WriteEnable && re1 == `ReadEnable) begin
            // ��дͬһ���Ĵ�����ֱ�ӷ���д�������
            rdata1 <= wdata;
        end else if(re1 == `ReadEnable) begin
            // ������򷵻�����
            rdata1 <= regs[raddr1];
        end else begin
            // ���򷵻�0
            rdata1 <= `ZeroWord;
        end
    end

    // ͬ�ϣ������Ǵ�����˿�2
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
