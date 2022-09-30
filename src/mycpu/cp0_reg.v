//////////////////////////////////////////////////////////////////////////////////
// CP0�Ĵ���
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
    input wire[4:0] init_i, // Ӳ���ж�����

    output reg[`RegBus] status_o,
    output reg[`RegBus] cause_o,
    output reg[`RegBus] epc_o,

    // �쳣
    input wire exception_occured_i,
    input wire[4:0] exc_code_i,
    input wire[`RegBus] pc_i,
    input wire is_in_delayslot_i,
    input wire[`RegBus] bad_addr_i 
    );

    // CP0�ڲ��ļĴ���
    reg[`RegBus] badVAddr;
    reg[`RegBus] count;
    reg[`RegBus] compare;
    reg[`RegBus] status;
    reg[`RegBus] cause;
    reg[`RegBus] epc;
    reg[`RegBus] config0;
    reg[`RegBus] config1;
    reg[`RegBus] errorEPC;

    // ������
    initial begin
        count <= `ZeroWord;
    end

    // �ų�status��cause��epc���������
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
                    status_o[31:29] <= wdata_i[31:29]; // CP0ʼ�տ��ã�������д��
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

    // д����
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            // ��λ������ָ���ֵ
            // ֻ����Ҫ����Ĳ��У����reset��Ϊundefined����Ҫ����
            status <= 32'b0000_0000_0100_0000_0000_0000_0000_0100;
            cause <= `ZeroWord;
            // TODO TLB cache things...
            config0 <= 32'b1000_0000_0000_0000_0000_0000_0000_0000;
            config1 <= `ZeroWord;
        end else begin
            // count����
            count <= count + 1;
            // ������ʱ���ж�
            // MIPS32R1�н���ʱ�������ܼ������ж���IP7�ϲ�
            // �ϲ���ʽȡ���ھ���ʵ�֣�HikariMIPSֱ��ʹ��ʱ���ж϶�ռIP7
            cause[15] <= count == compare ? 1'b1 : cause[15];
            // д�ⲿӲ���ж���casue
            cause[14:10] <= init_i;
        end 
        if (we_i == `WriteEnable) begin
            // ����Addrд����
            case (waddr_i)
                `CountAddr: begin
                    count <= wdata_i;
                end
                `CompareAddr: begin
                    compare <= wdata_i;
                    cause[15] <= 1'b0;
                end
                `StatusAddr: begin
                    status[31:29] <= wdata_i[31:29]; // CP0ʼ�տ��ã�������д��
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
                    config0[24:16] <= wdata_i[24:16]; // ����ʵ��ʹ��
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
            // �����쳣�����ļĴ����䶯��ERET���ܸ���EPC
            if (exception_occured_i && exc_code_i != 5'h10) begin
                // �������쳣���ȼ�¼EPC
                if (is_in_delayslot_i) begin
                    // ���ӳٲ���
                    epc <= pc_i - 4;
                    cause[31] <= 1'b1;
                end else begin
                    epc <= pc_i;
                end
                status[1] <= 1'b1; // �趨������������ģʽ�����쳣��
                cause[6:2] <= exc_code_i; // ����ԭ��
                // ����Բ�ͬ�쳣����������Ϊ���������BadVAddr��
                case (exc_code_i)
                    5'h04, 5'h05: begin
                        // ��ַ����쳣����BadVAddr
                        badVAddr <= bad_addr_i;
                    end 
                    default: begin
                    end
                endcase
            end
            // ERET�����쳣��
            if (exception_occured_i && exc_code_i == 5'h10) begin
                status[2] <= 1'b0;
                status[1] <= 1'b0;
            end
        end
    end

    // ������
    always @ (*) begin
        if (rst == `RstEnable) begin
            // ��λ���0
            rdata_o <= `ZeroWord;
        end else begin
            // ������
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
                // д���ȣ����ּĴ���ֻ��д���֣����Ҫƴ�Ӻ���Ϊ�����ݷ���
                // ���������ȡ�Ľ�������У�
                case (waddr_i)
                    `CountAddr, `CompareAddr, `EPCAddr, `ErrorEPCAddr: begin
                        rdata_o <= wdata_i;
                    end
                    `StatusAddr: begin
                        rdata_o[31:29] <= wdata_i[31:29]; // CP0ʼ�տ��ã�������д��
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
                        rdata_o[24:16] <= wdata_i[24:16]; // ����ʵ��ʹ��
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