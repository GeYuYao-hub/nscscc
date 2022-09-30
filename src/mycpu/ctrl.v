//////////////////////////////////////////////////////////////////////////////////
// CTRL流水线控制
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

    // 异常
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
            // 有异常
            flush <= 1'b1;
            case (exc_code_i)
                // 根据异常类型判断pc要写入的值
                5'h10: begin
                    // ERET调用
                    epc_o <= cp0_epc_i;
                end 
                default: begin
                    // 其他异常统一入口
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
            stall <= 6'b000111; // ID跟着暂停，应该可以解决跳转的问题
            // TODO 与MEM竞争被仲裁等待时，ID是否应该额外暂停？         
        end else begin
            stall <= 6'b000000;
        end
    end

endmodule