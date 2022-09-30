//////////////////////////////////////////////////////////////////////
// 32位除法器，直接使用IP核
//////////////////////////////////////////////////////////////////////
`include "defines.v"

module div(

    input wire clk,
    input wire rst,
    
    // 1 -> 有符号除法
    input wire signed_div_i,
    // 被除数
    input wire[31:0] opdata1_i,
	// 除数
    input wire[31:0] opdata2_i,
	// 1 -> 开始除法运算
    input wire start_i,
	// 1 -> 取消除法
    input wire annul_i,
    
	// 运算结果，高32位是商，低32位是余数
    output reg[63:0] result_o,
	// 1 -> 运算结束
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
                2'b00: begin // 尚未开始
                    if(start_i && annul_i == 1'b0) begin
                        // 没被取消，且要求开始
                        if(opdata2_i == 32'd0) begin
                            // 除数是0，进入计算出错状态
                            state <= 2'b11;
                        end else begin
                            // 准备开始
                            state <= 2'b01;
                            // 判断有无符号
                            if(signed_div_i) begin
                                signed_start <= 1'b1;
                            end else begin
                                unsigned_start <= 1'b1;
                            end
                        end
                    end else begin
                        // 没有开始或被取消
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end
                end
                2'b01: begin // 正在计算
                    signed_start <= 1'b0;
                    unsigned_start <= 1'b0;
                    if(annul_i == 1'b0) begin
                        // 没有被取消，等待dout tvalid信号
                        if(signed_div_i && signed_dout_valid) begin
                            // 有符号结果
                            result_o <= signed_result;  
                            ready_o <= 1'b1;
                            state <= 2'b10; // 计算完成
                        end else if (signed_div_i == 1'b0 && unsigned_dout_valid) begin
                            // 无符号结果
                            result_o <= unsigned_result;  
                            state <= 2'b10; // 计算完成
                        end else begin
                            // do nothing
                        end
                    end else begin
                        // 被取消
                        state <= 2'b00;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end    
                end
                2'b10: begin // 计算完成
					ready_o <= 1'b1;
                    if(start_i == 1'b0) begin
                        // 运算结束
                        state <= 2'b00; // 恢复等待
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end else begin
                        
                    end
                end
                default : begin // 计算出错
                    state <= 2'b10;  
                    ready_o <= 1'b0;
                    result_o <= 64'd0;
                end
            endcase
        end
    end

endmodule