//////////////////////////////////////////////////////////////////////////////////
// �˷���
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module mul(

    input wire clk,
    input wire rst,
    
    // 1 -> �з���
    input wire signed_mul_i,
    input wire[31:0] opdata1_i,
    input wire[31:0] opdata2_i,
	// 1 -> ��ʼ
    input wire start_i,
	// 1 -> ȡ��
    input wire annul_i,
    
    output reg[63:0] result_o,
	// 1 -> �������
    output reg ready_o
    );

    reg[1:0] state;
    reg[3:0] count;

    wire[63:0] signed_result;
    signed_multiplier signed_multiplier(
        .CLK(~clk),
        .A(opdata1_i),
        .B(opdata2_i),
        .P(signed_result)
    );

    wire[63:0] unsigned_result;

    unsigned_multiplier unsigned_multiplier(
        .CLK(~clk),
        .A(opdata1_i),
        .B(opdata2_i),
        .P(unsigned_result)
    );

    always @ (posedge clk) begin
        if (rst) begin
            state <= 2'b00;
            count <= 0;
            ready_o <= 1'b0;
            result_o <= 64'd0;
        end else begin
            case (state)
                2'b00: begin // ��δ��ʼ
                    if(start_i && annul_i == 1'b0) begin
                        // û��ȡ������Ҫ��ʼ
                        state <= 2'b01;
                        count <= count + 1;
                    end else begin
                        // û�п�ʼ��ȡ��
                        count <= 0;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end
                end
                2'b01: begin // ���ڼ���
                    if(annul_i == 1'b0) begin
                        count <= count + 1;
                        // û�б�ȡ�����ȴ�
                        // �����Ƿ�������ֵ���ڵ��������ڳ����
                        // �����countΪ5��ʱ���Ҫ��ת���������״̬���˹�������һ������
                        // ��ʼ��һ��ִ�м������ʱcountΪ6����ȡ��������
                        if(count == 11) begin
                            state <= 2'b10; // �������
                        end else begin
                        end
                    end else begin
                        // ��ȡ��
                        state <= 2'b00;
                        count <= 0;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end    
                end
                2'b10: begin // �������
                    if(signed_mul_i) begin
                        // �з��Ž��
                        result_o <= signed_result;
                    end else begin
                        // �޷��Ž��
                        result_o <= unsigned_result;
                    end 
                    ready_o <= 1'b1;
                    if(start_i == 1'b0) begin
                        // �������
                        state <= 2'b00; // �ָ��ȴ�
                        count <= 0;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end else begin
                        
                    end
                end
                default: begin // �������
                    state <= 2'b10;  
                    count <= 0;
                    ready_o <= 1'b0;
                    result_o <= 64'd0;
                end
            endcase
        end
    end

endmodule
