//////////////////////////////////////////////////////////////////////////////////
// CTRL��ˮ�߿���
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module ctrl(
    input wire clk,
    input wire rst,

    input wire stallreq_from_if,
    input wire stallreq_from_id,
    input wire stallreq_from_ex,
    input wire stallreq_from_mem,
    // stall <= {WB, MEM, EX, ID, IF, PC}
    output reg[5:0] stall,

    // �쳣
    input wire[`RegBus] cp0_epc_i,
    input wire exception_occured_i,
    input wire[4:0] exc_code_i,
    output reg[`RegBus] epc_o,
    output reg flush
);
    always @ (*) begin
        stall <= 6'b000000;
        flush <= 1'b0;
        if(rst == `RstEnable) begin
            epc_o <= `ZeroWord;
        end else if(exception_occured_i) begin
            // ���쳣
            flush <= 1'b1;
            case (exc_code_i)
                // �����쳣�����ж�pcҪд���ֵ
                5'h10: begin
                    // ERET����
                    epc_o <= cp0_epc_i;
                end 
                default: begin
                    // �����쳣ͳһ���
                    epc_o <= 32'hBFC00380;
                end
            endcase
        end else if(stallreq_from_mem == `Stop) begin
            stall <= 6'b011111;
        end else if(stallreq_from_ex == `Stop) begin
            stall <= 6'b001111;
        end else if(stallreq_from_id == `Stop) begin
            stall <= 6'b000111;            
        end else if(stallreq_from_if == `Stop) begin
            stall <= 6'b000111; // ID������ͣ��Ӧ�ÿ��Խ����ת������
            // TODO ��MEM�������ٲõȴ�ʱ��ID�Ƿ�Ӧ�ö�����ͣ��         
        end else begin
            stall <= 6'b000000;
        end
    end

endmodule