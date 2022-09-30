//////////////////////////////////////////////////////////////////////
// 32λ��������ֱ��ʹ��IP��
//////////////////////////////////////////////////////////////////////
`include "defines.v"

module div(

    input wire clk,
    input wire rst,
    
    // 1 -> �з��ų���
    input wire signed_div_i,
    // ������
    input wire[31:0] opdata1_i,
	// ����
    input wire[31:0] opdata2_i,
	// 1 -> ��ʼ��������
    input wire start_i,
	// 1 -> ȡ������
    input wire annul_i,
    
	// ����������32λ���̣���32λ������
    output reg[63:0] result_o,
	// 1 -> �������
    output reg ready_o
);

    reg[1:0] state;

    reg signed_start;
    wire[63:0] signed_result;
    wire signed_dout_valid;

    signed_divider signed_divider(
	    .aclk(clk),
        .s_axis_dividend_tdata(opdata1_i),
        .s_axis_dividend_tvalid(signed_start),
        .s_axis_divisor_tdata(opdata2_i),
        .s_axis_divisor_tvalid(signed_start),
        .m_axis_dout_tdata(signed_result),
        .m_axis_dout_tvalid(signed_dout_valid)
    );

    reg unsigned_start;
    wire[63:0] unsigned_result;
    wire unsigned_dout_valid;

    unsigned_divider unsigned_divider(
	    .aclk(clk),
        .s_axis_dividend_tdata(opdata1_i),
        .s_axis_dividend_tvalid(unsigned_start),
        .s_axis_divisor_tdata(opdata2_i),
        .s_axis_divisor_tvalid(unsigned_start),
        .m_axis_dout_tdata(unsigned_result),
        .m_axis_dout_tvalid(unsigned_dout_valid)
    );

    always @ (posedge clk) begin
        if (rst) begin
            signed_start <= 1'b0;
            unsigned_start <= 1'b0;
            state <= 2'b00;
            ready_o <= 1'b0;
            result_o <= 64'd0;
        end else begin
            case (state)
                2'b00: begin // ��δ��ʼ
                    if(start_i && annul_i == 1'b0) begin
                        // û��ȡ������Ҫ��ʼ
                        if(opdata2_i == 32'd0) begin
                            // ������0������������״̬
                            state <= 2'b11;
                        end else begin
                            // ׼����ʼ
                            state <= 2'b01;
                            // �ж����޷���
                            if(signed_div_i) begin
                                signed_start <= 1'b1;
                            end else begin
                                unsigned_start <= 1'b1;
                            end
                        end
                    end else begin
                        // û�п�ʼ��ȡ��
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end
                end
                2'b01: begin // ���ڼ���
                    signed_start <= 1'b0;
                    unsigned_start <= 1'b0;
                    if(annul_i == 1'b0) begin
                        // û�б�ȡ�����ȴ�dout tvalid�ź�
                        if(signed_div_i && signed_dout_valid) begin
                            // �з��Ž��
                            result_o <= signed_result;  
                            ready_o <= 1'b1;
                            state <= 2'b10; // �������
                        end else if (signed_div_i == 1'b0 && unsigned_dout_valid) begin
                            // �޷��Ž��
                            result_o <= unsigned_result;  
                            state <= 2'b10; // �������
                        end else begin
                            // do nothing
                        end
                    end else begin
                        // ��ȡ��
                        state <= 2'b00;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end    
                end
                2'b10: begin // �������
					ready_o <= 1'b1;
                    if(start_i == 1'b0) begin
                        // �������
                        state <= 2'b00; // �ָ��ȴ�
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end else begin
                        
                    end
                end
                default : begin // �������
                    state <= 2'b10;  
                    ready_o <= 1'b0;
                    result_o <= 64'd0;
                end
            endcase
        end
    end

endmodule