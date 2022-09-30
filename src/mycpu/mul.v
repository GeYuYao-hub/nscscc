//////////////////////////////////////////////////////////////////////////////////
// 乘法器
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module mul(

    input wire clk,
    input wire rst,
    
    // 1 -> 有符号
    input wire signed_mul_i,
    input wire[31:0] opdata1_i,
    input wire[31:0] opdata2_i,
	// 1 -> 开始
    input wire start_i,
	// 1 -> 取消
    input wire annul_i,
    
    output reg[63:0] result_o,
	// 1 -> 运算结束
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
                2'b00: begin // 尚未开始
                    if(start_i && annul_i == 1'b0) begin
                        // 没被取消，且要求开始
                        state <= 2'b01;
                        count <= count + 1;
                    end else begin
                        // 没有开始或被取消
                        count <= 0;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end
                end
                2'b01: begin // 正在计算
                    if(annul_i == 1'b0) begin
                        count <= count + 1;
                        // 没有被取消，等待
                        // 由于是非阻塞赋值，在第六个周期出结果
                        // 因此在count为5的时候就要跳转到计算完成状态，此过程消耗一个周期
                        // 开始第一次执行计算完成时count为6，拿取并输出结果
                        if(count == 11) begin
                            state <= 2'b10; // 计算完成
                        end else begin
                        end
                    end else begin
                        // 被取消
                        state <= 2'b00;
                        count <= 0;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end    
                end
                2'b10: begin // 计算完成
                    if(signed_mul_i) begin
                        // 有符号结果
                        result_o <= signed_result;
                    end else begin
                        // 无符号结果
                        result_o <= unsigned_result;
                    end 
                    ready_o <= 1'b1;
                    if(start_i == 1'b0) begin
                        // 运算结束
                        state <= 2'b00; // 恢复等待
                        count <= 0;
                        ready_o <= 1'b0;
                        result_o <= 64'd0;
                    end else begin
                        
                    end
                end
                default: begin // 计算出错
                    state <= 2'b10;  
                    count <= 0;
                    ready_o <= 1'b0;
                    result_o <= 64'd0;
                end
            endcase
        end
    end

endmodule
