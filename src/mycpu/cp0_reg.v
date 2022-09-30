//////////////////////////////////////////////////////////////////////////////////
// CP0寄存器
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module cp0_reg(
    input wire clk,
    input wire rst,

    input wire we_i,
    input wire[7:0] waddr_i, // [7:3] number, [2:0] sel
    input wire[`RegBus] wdata_i,

    input wire[7:0] raddr_i,
    output reg[`RegBus] rdata_o,
    input wire[4:0] init_i, // 硬件中断输入

    output reg[`RegBus] status_o,
    output reg[`RegBus] cause_o,
    output reg[`RegBus] epc_o,

    // 异常
    input wire exception_occured_i,
    input wire[4:0] exc_code_i,
    input wire[`RegBus] pc_i,
    input wire is_in_delayslot_i,
    input wire[`RegBus] bad_addr_i 
    );

    // CP0内部的寄存器
    reg[`RegBus] badVAddr;
    reg[`RegBus] count;
    reg[`RegBus] compare;
    reg[`RegBus] status;
    reg[`RegBus] cause;
    reg[`RegBus] epc;
    reg[`RegBus] config0;
    reg[`RegBus] config1;
    reg[`RegBus] errorEPC;

    // 仿真用
    initial begin
        count <= `ZeroWord;
    end

    // 排除status、cause和epc的数据相关
    always @ (*) begin
        status_o <= status;
        cause_o <= cause;
        epc_o <= epc;
        if (rst == `RstEnable) begin
            status_o <= `ZeroWord;
            cause_o <= `ZeroWord;
            epc_o <= `ZeroWord;
        end else if (we_i == `WriteEnable) begin
            case (waddr_i)
                `StatusAddr: begin
                    status_o[31:29] <= wdata_i[31:29]; // CP0始终可用，不允许写入
                    status_o[22] <= wdata_i[22];
                    status_o[15:8] <= wdata_i[15:8];
                    status_o[4] <= wdata_i[4];
                    status_o[2:0] <= wdata_i[2:0];
                end
                `CauseAddr: begin
                    cause_o[23] <= wdata_i[23];
                    cause_o[9:8] <= wdata_i[9:8];
                end
                `EPCAddr: begin
                    epc_o <= wdata_i;
                end
                default: begin
                end
            endcase 
        end else begin
        end
    end

    // 写数据
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            // 复位，按照指令集赋值
            // 只有需要清零的才有，如果reset后为undefined则不需要清零
            status <= 32'b0000_0000_0100_0000_0000_0000_0000_0100;
            cause <= `ZeroWord;
            // TODO TLB cache things...
            config0 <= 32'b1000_0000_0000_0000_0000_0000_0000_0000;
            config1 <= `ZeroWord;
        end else begin
            // count自增
            count <= count + 1;
            // 引发定时器中断
            // MIPS32R1中将定时器和性能计数器中断与IP7合并
            // 合并方式取决于具体实现，HikariMIPS直接使定时器中断独占IP7
            cause[15] <= count == compare ? 1'b1 : cause[15];
            // 写外部硬件中断至casue
            cause[14:10] <= init_i;
        end 
        if (we_i == `WriteEnable) begin
            // 根据Addr写数据
            case (waddr_i)
                `CountAddr: begin
                    count <= wdata_i;
                end
                `CompareAddr: begin
                    compare <= wdata_i;
                    cause[15] <= 1'b0;
                end
                `StatusAddr: begin
                    status[31:29] <= wdata_i[31:29]; // CP0始终可用，不允许写入
                    status[22] <= wdata_i[22];
                    status[15:8] <= wdata_i[15:8];
                    status[4] <= wdata_i[4];
                    status[2:0] <= wdata_i[2:0];
                end
                `CauseAddr: begin
                    cause[23] <= wdata_i[23];
                    cause[9:8] <= wdata_i[9:8];
                end
                `EPCAddr: begin
                    epc <= wdata_i;
                end
                `Config0Addr: begin
                    config0[30:25] <= wdata_i[30:25];
                    config0[24:16] <= wdata_i[24:16]; // 具体实现使用
                    config0[2:0] <= wdata_i[2:0];
                end
                `ErrorEPCAddr: begin
                    errorEPC <= wdata_i;
                end
                default: begin
                    // unknown register
                end
            endcase 
        end

        if (rst == `RstDisable) begin
            // 处理异常产生的寄存器变动，ERET不能更新EPC
            if (exception_occured_i && exc_code_i != 5'h10) begin
                // 发生了异常，先记录EPC
                if (is_in_delayslot_i) begin
                    // 在延迟槽内
                    epc <= pc_i - 4;
                    cause[31] <= 1'b1;
                end else begin
                    epc <= pc_i;
                end
                status[1] <= 1'b1; // 设定处理器从正常模式进入异常级
                cause[6:2] <= exc_code_i; // 保存原因
                // 再针对不同异常进行其他行为（例如更新BadVAddr）
                case (exc_code_i)
                    5'h04, 5'h05: begin
                        // 地址相关异常更新BadVAddr
                        badVAddr <= bad_addr_i;
                    end 
                    default: begin
                    end
                endcase
            end
            // ERET重置异常级
            if (exception_occured_i && exc_code_i == 5'h10) begin
                status[2] <= 1'b0;
                status[1] <= 1'b0;
            end
        end
    end

    // 读数据
    always @ (*) begin
        if (rst == `RstEnable) begin
            // 复位输出0
            rdata_o <= `ZeroWord;
        end else begin
            // 正常读
            case (raddr_i)
                `BadVAddrAddr: begin
                    rdata_o <= badVAddr;
                end
                `CountAddr: begin
                    rdata_o <= count;
                end
                `CompareAddr: begin
                    rdata_o <= compare;
                end
                `StatusAddr: begin
                    rdata_o <= status;
                end
                `CauseAddr: begin
                    rdata_o <= cause;
                end
                `EPCAddr: begin
                    rdata_o <= epc;
                end
                `Config0Addr: begin
                    rdata_o <= config0;
                end
                `Config1Addr: begin
                    rdata_o <= config1;
                end
                `ErrorEPCAddr: begin
                    rdata_o <= errorEPC;
                end
                default: begin
                    // unknown register
                    rdata_o <= `ZeroWord;
                end
            endcase

            if (we_i == `WriteEnable && raddr_i == waddr_i) begin
                // 写优先，部分寄存器只能写部分，因此要拼接后作为读数据返回
                // 覆盖上面读取的结果（若有）
                case (waddr_i)
                    `CountAddr, `CompareAddr, `EPCAddr, `ErrorEPCAddr: begin
                        rdata_o <= wdata_i;
                    end
                    `StatusAddr: begin
                        rdata_o[31:29] <= wdata_i[31:29]; // CP0始终可用，不允许写入
                        rdata_o[22] <= wdata_i[22];
                        rdata_o[15:8] <= wdata_i[15:8];
                        rdata_o[4] <= wdata_i[4];
                        rdata_o[2:0] <= wdata_i[2:0];
                    end
                    `CauseAddr: begin
                        rdata_o[23] <= wdata_i[23];
                        rdata_o[9:8] <= wdata_i[9:8];
                    end
                    `Config0Addr: begin
                        rdata_o[30:25] <= wdata_i[30:25];
                        rdata_o[24:16] <= wdata_i[24:16]; // 具体实现使用
                        rdata_o[2:0] <= wdata_i[2:0];
                    end
                    default: begin
                        // unknown register
                    end
                endcase
            end else begin
            end
        end
    end

endmodule