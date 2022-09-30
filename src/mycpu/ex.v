//////////////////////////////////////////////////////////////////////////////////
// ִ�н׶�
// �ں�ALU����
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module ex(
    input wire clk,
    input wire rst,
    
    //�͵�ִ�н׶ε���Ϣ
    input wire[`AluOpBus] aluop_i,
    input wire[`AluSelBus] alusel_i,
    input wire[`RegBus] reg1_i,
    input wire[`RegBus] reg2_i,
    input wire[`RegAddrBus] waddr_i,
    input wire we_i,
    input wire[`RegBus] inst_i,
    input wire[`RegBus] pc_i,
    input wire[31:0] exceptions_i,

    // hi/LO�Ĵ���
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,
    // ���Էô�ķ�����ͬIDģ����������ص�˼·    
    input wire[`RegBus] mem_hi_i,
    input wire[`RegBus] mem_lo_i,
    input wire mem_we_hilo_i,

    // CP0�Ĵ���
    input wire[`RegBus] cp0_rdata_i,
    output reg[7:0] cp0_raddr_o,
    output reg cp0_we_o,
    output reg[7:0] cp0_waddr_o,
    output reg[`RegBus] cp0_wdata_o,
    // ����MEM�ķ���������������
    input wire mem_cp0_we_i,
    input wire[7:0] mem_cp0_waddr_i,
    input wire[`RegBus] mem_cp0_wdata_i,

    // �͵��ô�׶ε���Ϣ
    // �ô�ת��д�ص�����
    output reg[`RegAddrBus] waddr_o,
    output reg we_o,
    output reg[`RegBus] wdata_o,
    output reg we_hilo_o,
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    // �����ô�ģ����Ϊ�Ĳ���
    output wire[`AluOpBus] aluop_o,
    output wire[`RegBus] mem_addr_o,
    // rt�Ĵ������ݣ�LWL��Щ�����޸ļĴ�����һ����
    output wire[`RegBus] reg2_o, 

    // �ӳٲۺ���ת
    input wire[`RegBus] link_address_i,
    input wire is_in_delayslot_i,

    // �쳣
    output wire[`RegBus] pc_o,
    output wire[31:0] exceptions_o,
    output wire is_in_delayslot_o,

    // ����ģ��
    input wire[`DoubleRegBus] div_result_i,
    input wire div_ready_i,
    output reg[`RegBus] div_opdata1_o,
    output reg[`RegBus] div_opdata2_o,
    output reg div_start_o,
    output reg signed_div_o,
    
    // �˷�ģ��
    input wire[`DoubleRegBus] mult_result_i,
    input wire mult_ready_i,
    output reg[`RegBus] mult_opdata1_o,
    output reg[`RegBus] mult_opdata2_o,
    output reg mult_start_o,
    output reg signed_mult_o,

    output reg stallreq
    );

    reg trap_occured;
    reg overflow_occured;
    assign pc_o = pc_i;
    assign is_in_delayslot_o = is_in_delayslot_i;
    // IF IDʹ���˵���λ�������������λ��ʾ��������ݣ�����Ӧ��Ϊ0
    assign exceptions_o = {exceptions_i[31:7], trap_occured, overflow_occured, exceptions_i[4:0]};

    reg[`RegBus] logic_result;
    reg[`RegBus] shift_result;
    reg[`RegBus] move_result;
    reg[`RegBus] arithmetic_result;

    reg stallreq_for_div; // �������ͣ��ˮ��
    reg stallreq_for_mult; // ��˷���ͣ��ˮ��

    // ����洢�ų�������غ��HI/LO�Ĵ���ֵ
    reg[`RegBus] HI;
    reg[`RegBus] LO;

    // ���ݵ�MEM�Ĳ���
    assign aluop_o = aluop_i;
    // reg1_i = base�����16λoffset�з�����չ�����
    assign mem_addr_o = reg1_i + { {16{inst_i[15]}}, inst_i[15:0]};
    // �����ǵļĴ���ԭ���ݣ���LWL��ָ��ʹ��
    assign reg2_o = reg2_i;

    // ����߼���·���������ź�����
    // �߼�����
    always @ (*) begin
        if(rst == `RstEnable) begin
            logic_result <= `ZeroWord;
        end else begin
        case (aluop_i)
            `ALU_OP_OR: begin
                logic_result <= reg1_i | reg2_i;
            end
            `ALU_OP_AND: begin
                logic_result <= reg1_i & reg2_i;
            end
            `ALU_OP_NOR: begin
                logic_result <= ~(reg1_i | reg2_i);
            end
            `ALU_OP_XOR: begin
                logic_result <= reg1_i ^ reg2_i;
            end
            default: begin
                logic_result <= `ZeroWord;
            end
        endcase
        end
    end

    // λ������
    always @ (*) begin
        if(rst == `RstEnable) begin
            shift_result <= `ZeroWord;
        end else begin
        case (aluop_i)
            `ALU_OP_SLL: begin
                shift_result <= reg2_i << reg1_i[4:0];
            end
            `ALU_OP_SRL: begin
                shift_result <= reg2_i >> reg1_i[4:0];
            end
            `ALU_OP_SRA: begin
                // �ȸ��ݷ���λ��������Ĳ��֣�������Ϊ�˷����������ƴ��
                shift_result <= ({32{reg2_i[31]}} << (6'd32-{1'b0, reg1_i[4:0]})) | reg2_i >> reg1_i[4:0];
            end
            default: begin
                shift_result <= `ZeroWord;
            end
        endcase
        end
    end

    // �ų�HI/LO�������
    always @ (*) begin
        if(rst == `RstEnable) begin
            {HI,LO} <= {`ZeroWord,`ZeroWord};
        end else if(mem_we_hilo_i == `WriteEnable) begin
            {HI,LO} <= {mem_hi_i,mem_lo_i};
        end else begin
            {HI,LO} <= {hi_i,lo_i};            
        end
    end

    // �����ƶ���дRegfile���֣�ֻ�漰MFxxָ��
    wire[7:0] cp0_addr = {inst_i[15:11], inst_i[2:0]};
    always @ (*) begin
        if(rst == `RstEnable) begin
            move_result <= `ZeroWord;
        end else begin
            move_result <= `ZeroWord;
            case (aluop_i)
                `ALU_OP_MFHI: begin
                    move_result <= HI;
                end
                `ALU_OP_MFLO: begin
                    move_result <= LO;
                end
                `ALU_OP_MOV: begin
                    move_result <= reg1_i;
                end
                `ALU_OP_MFC0: begin
                    cp0_raddr_o <= cp0_addr;
                    // �����������
                    if (mem_cp0_we_i && mem_cp0_waddr_i == cp0_addr) begin
                        move_result <= mem_cp0_wdata_i;
                    end else begin
                        // û���������
                        move_result <= cp0_rdata_i;
                    end
                end
                default : begin
                end
            endcase
        end
    end

    // �������㲿��
    // ���ȼ�����ڶ�������������������SLT��С����1��ʱ�൱��+[-y]��
    wire[`RegBus] reg2_i_mux = ( aluop_i == `ALU_OP_SUB 
                                || aluop_i == `ALU_OP_SUBU
                                || aluop_i == `ALU_OP_SLT 
                                || aluop_i == `ALU_OP_TLT 
                                || aluop_i == `ALU_OP_TGE ) ? ~reg2_i + 1 : reg2_i;
    // ����Ӽ��ͣ�����Ǽӷ�������������ͣ�����Ǽ�����Ƚϣ���������ǲ�
    wire[`RegBus] result_sum = reg1_i + reg2_i_mux;
    // ������������Ϊ����Ϊ����������Ϊ����Ϊ��
    wire sum_overflow = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31])); 
    // reg1�Ƿ�С��reg2�����������
    // �з�������reg1 2�ķ��ź�result_sum�ķ��ţ�����һ��һ�����ȻС��
    // �޷�����ֱ�ӱȽ����߷���
    wire reg1_lt_reg2 = (aluop_i == `ALU_OP_SLTU || aluop_i == `ALU_OP_TLTU || aluop_i == `ALU_OP_TGEU ) ? (reg1_i < reg2_i) : ( (reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i[31] && result_sum[31]) || (reg1_i[31] && reg2_i[31] && result_sum[31]) );
    // reg1ȡ��
    wire[`RegBus] reg1_not = ~reg1_i;

    // ������������
    always @ (*) begin
        if(rst == `RstEnable) begin
            arithmetic_result <= `ZeroWord;
        end else begin
            case (aluop_i)
                `ALU_OP_SLT, `ALU_OP_SLTU: begin
                    arithmetic_result <= reg1_lt_reg2 ;
                end
                `ALU_OP_ADD, `ALU_OP_ADDU: begin
                    arithmetic_result <= result_sum[31:0]; 
                end
                `ALU_OP_SUB, `ALU_OP_SUBU: begin
                    arithmetic_result <= result_sum[31:0]; 
                end
                `ALU_OP_CLZ: begin
                    arithmetic_result <= reg1_i[31] ? 0 : 
                                         reg1_i[30] ? 1 : 
                                         reg1_i[29] ? 2 :
                                         reg1_i[28] ? 3 : 
                                         reg1_i[27] ? 4 : 
                                         reg1_i[26] ? 5 :
                                         reg1_i[25] ? 6 : 
                                         reg1_i[24] ? 7 : 
                                         reg1_i[23] ? 8 : 
                                         reg1_i[22] ? 9 : 
                                         reg1_i[21] ? 10 : 
                                         reg1_i[20] ? 11 :
                                         reg1_i[19] ? 12 : 
                                         reg1_i[18] ? 13 : 
                                         reg1_i[17] ? 14 : 
                                         reg1_i[16] ? 15 : 
                                         reg1_i[15] ? 16 : 
                                         reg1_i[14] ? 17 : 
                                         reg1_i[13] ? 18 : 
                                         reg1_i[12] ? 19 : 
                                         reg1_i[11] ? 20 :
                                         reg1_i[10] ? 21 : 
                                         reg1_i[9] ? 22 : 
                                         reg1_i[8] ? 23 : 
                                         reg1_i[7] ? 24 : 
                                         reg1_i[6] ? 25 : 
                                         reg1_i[5] ? 26 : 
                                         reg1_i[4] ? 27 : 
                                         reg1_i[3] ? 28 : 
                                         reg1_i[2] ? 29 : 
                                         reg1_i[1] ? 30 : 
                                         reg1_i[0] ? 31 : 32 ;
                end
                `ALU_OP_CLO: begin
                    arithmetic_result <= reg1_not[31] ? 0 :
                                         reg1_not[30] ? 1 :
                                         reg1_not[29] ? 2 :
                                         reg1_not[28] ? 3 :
                                         reg1_not[27] ? 4 : 
                                         reg1_not[26] ? 5 :
                                         reg1_not[25] ? 6 :
                                         reg1_not[24] ? 7 : 
                                         reg1_not[23] ? 8 : 
                                         reg1_not[22] ? 9 :
                                         reg1_not[21] ? 10 : 
                                         reg1_not[20] ? 11 :
                                         reg1_not[19] ? 12 : 
                                         reg1_not[18] ? 13 : 
                                         reg1_not[17] ? 14 : 
                                         reg1_not[16] ? 15 : 
                                         reg1_not[15] ? 16 : 
                                         reg1_not[14] ? 17 : 
                                         reg1_not[13] ? 18 : 
                                         reg1_not[12] ? 19 : 
                                         reg1_not[11] ? 20 :
                                         reg1_not[10] ? 21 : 
                                         reg1_not[9] ? 22 : 
                                         reg1_not[8] ? 23 : 
                                         reg1_not[7] ? 24 : 
                                         reg1_not[6] ? 25 : 
                                         reg1_not[5] ? 26 : 
                                         reg1_not[4] ? 27 : 
                                         reg1_not[3] ? 28 : 
                                         reg1_not[2] ? 29 : 
                                         reg1_not[1] ? 30 : 
                                         reg1_not[0] ? 31 : 32 ;
                end
                default: begin
                    arithmetic_result <= `ZeroWord;
                end
            endcase
        end
    end
    // ��������Ľ���ж��Ƿ�����
    always @ (*) begin
        if (rst == `RstEnable) begin
            trap_occured <= `False_v;
        end else begin
            case (aluop_i)
                // TEQ TEQI
                `ALU_OP_TEQ: begin
                    trap_occured <= (reg1_i == reg2_i);
                end 
                // TEG TEGI TEGU TEGIU
                `ALU_OP_TGE, `ALU_OP_TGEU: begin
                    trap_occured <= (~reg1_lt_reg2); // not less than -> great equal than
                end
                // TLT TLTU TLTI TLTIU
                `ALU_OP_TLT, `ALU_OP_TLTU: begin
                    trap_occured <= reg1_lt_reg2;
                end
                // TNE TNEI
                `ALU_OP_TNE: begin
                    trap_occured <= (reg1_i != reg2_i);
                end
                default: begin
                    trap_occured <= `False_v; // Ĭ��û��
                end
            endcase
        end
    end

    // ����˷�
    always @ (*) begin
        if(rst == `RstEnable) begin
            stallreq_for_mult <= `NoStop;
            mult_opdata1_o <= `ZeroWord;
            mult_opdata2_o <= `ZeroWord;
            mult_start_o <= `ComputeStop;
            signed_mult_o <= 1'b0;
        end else begin
            stallreq_for_mult <= `NoStop;
            mult_opdata1_o <= `ZeroWord;
            mult_opdata2_o <= `ZeroWord;
            mult_start_o <= `ComputeStop;
            signed_mult_o <= 1'b0;     
            case (aluop_i) 
                `ALU_OP_MULT, `ALU_OP_MUL, `ALU_OP_MADD, `ALU_OP_MSUB: begin
                    if(mult_ready_i == `ResultNotReady) begin
                        mult_opdata1_o <= reg1_i;
                        mult_opdata2_o <= reg2_i;
                        mult_start_o <= `ComputeStart;
                        signed_mult_o <= 1'b1;
                        stallreq_for_mult <= `Stop;
                    end else if(mult_ready_i == `ResultReady) begin
                        mult_opdata1_o <= reg1_i;
                        mult_opdata2_o <= reg2_i;
                        mult_start_o <= `ComputeStop;
                        signed_mult_o <= 1'b1;
                        stallreq_for_mult <= `NoStop;
                    end else begin
                        mult_opdata1_o <= `ZeroWord;
                        mult_opdata2_o <= `ZeroWord;
                        mult_start_o <= `ComputeStop;
                        signed_mult_o <= 1'b0;
                        stallreq_for_mult <= `NoStop;
                    end                         
                end
                `ALU_OP_MULTU, `ALU_OP_MADDU, `ALU_OP_MSUBU: begin
                    if(mult_ready_i == `ResultNotReady) begin
                        mult_opdata1_o <= reg1_i;
                        mult_opdata2_o <= reg2_i;
                        mult_start_o <= `ComputeStart;
                        signed_mult_o <= 1'b0;
                        stallreq_for_mult <= `Stop;
                    end else if(mult_ready_i == `ResultReady) begin
                        mult_opdata1_o <= reg1_i;
                        mult_opdata2_o <= reg2_i;
                        mult_start_o <= `ComputeStop;
                        signed_mult_o <= 1'b0;
                        stallreq_for_mult <= `NoStop;
                    end else begin
                        mult_opdata1_o <= `ZeroWord;
                        mult_opdata2_o <= `ZeroWord;
                        mult_start_o <= `ComputeStop;
                        signed_mult_o <= 1'b0;
                        stallreq_for_mult <= `NoStop;
                    end                         
                end
                default: begin
                end
            endcase
        end
    end

    // �����ۼ��ۼ��˷�
    reg[`DoubleRegBus] accu_temp;
    always @ (*) begin
        if (rst == `RstEnable) begin
            // ��λ
            accu_temp <= {`ZeroWord, `ZeroWord};
        end else begin
            case (aluop_i)
                // MADD MADDU
                `ALU_OP_MADD, `ALU_OP_MADDU: begin
                    // �ȴ��˷�����
                    if (stallreq_for_mult != `Stop) begin
                        // �ۼ�
                        accu_temp <= mult_result_i + {HI, LO};
                    end begin
                        // do nothing
                    end
                end 
                // MSUB MSUBU
                `ALU_OP_MSUB, `ALU_OP_MSUBU: begin
                    // �ȴ��˷�����
                    if (stallreq_for_mult != `Stop) begin
                        accu_temp <= ~mult_result_i + 1 + {HI, LO}; // �ۼ�
                    end begin
                        // do nothing
                    end
                end 
                default: begin
                    // ���ۼ�ָ�ͬ��λ
                    accu_temp <= {`ZeroWord, `ZeroWord};
                end
            endcase
        end
    end

    // �������
    always @ (*) begin
        if(rst == `RstEnable) begin
            stallreq_for_div <= `NoStop;
            div_opdata1_o <= `ZeroWord;
            div_opdata2_o <= `ZeroWord;
            div_start_o <= `ComputeStop;
            signed_div_o <= 1'b0;
        end else begin
            stallreq_for_div <= `NoStop;
            div_opdata1_o <= `ZeroWord;
            div_opdata2_o <= `ZeroWord;
            div_start_o <= `ComputeStop;
            signed_div_o <= 1'b0;     
            case (aluop_i) 
                `ALU_OP_DIV: begin
                    if(div_ready_i == `ResultNotReady) begin
                        div_opdata1_o <= reg1_i;
                        div_opdata2_o <= reg2_i;
                        div_start_o <= `ComputeStart;
                        signed_div_o <= 1'b1;
                        stallreq_for_div <= `Stop;
                    end else if(div_ready_i == `ResultReady) begin
                        div_opdata1_o <= reg1_i;
                        div_opdata2_o <= reg2_i;
                        div_start_o <= `ComputeStop;
                        signed_div_o <= 1'b1;
                        stallreq_for_div <= `NoStop;
                    end else begin
                        div_opdata1_o <= `ZeroWord;
                        div_opdata2_o <= `ZeroWord;
                        div_start_o <= `ComputeStop;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `NoStop;
                    end                         
                end
                `ALU_OP_DIVU: begin
                    if(div_ready_i == `ResultNotReady) begin
                        div_opdata1_o <= reg1_i;
                        div_opdata2_o <= reg2_i;
                        div_start_o <= `ComputeStart;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `Stop;
                    end else if(div_ready_i == `ResultReady) begin
                        div_opdata1_o <= reg1_i;
                        div_opdata2_o <= reg2_i;
                        div_start_o <= `ComputeStop;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `NoStop;
                    end else begin
                        div_opdata1_o <= `ZeroWord;
                        div_opdata2_o <= `ZeroWord;
                        div_start_o <= `ComputeStop;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `NoStop;
                    end                         
                end
                default: begin
                end
            endcase
        end
    end

    // ������ͣ����
    always @ (*) begin
        // �����ܵ���ͣ����֮��
        stallreq <= stallreq_for_div || stallreq_for_mult;
    end

    // �����ƶ���дHI/LO���֣�ֻ�漰MTHI/LOָ��
    // ͬʱ����д��˳������
    always @ (*) begin
        if(rst == `RstEnable) begin
            we_hilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;

            lo_o <= `ZeroWord;
        end else if(aluop_i == `ALU_OP_MULT || aluop_i == `ALU_OP_MULTU) begin
            // �ǳ˷������д��HILO��MULָ�����
            we_hilo_o <= `WriteEnable;
            hi_o <= mult_result_i[63:32];
            lo_o <= mult_result_i[31:0];
        end else if (aluop_i == `ALU_OP_DIV || aluop_i == `ALU_OP_DIVU) begin
            // ���� ��32λ���̣���32λ������
            we_hilo_o <= `WriteEnable;
            hi_o <= div_result_i[31:0];
            lo_o <= div_result_i[63:32];
        end else if (aluop_i == `ALU_OP_MADD || aluop_i == `ALU_OP_MADDU || aluop_i == `ALU_OP_MSUB || aluop_i == `ALU_OP_MSUBU) begin
            // �ۼӡ��ۼ�
            we_hilo_o <= `WriteEnable;
            hi_o <= accu_temp[63:32];
            lo_o <= accu_temp[31:0];
            // �����ڸ��׶ζ��ᴫ�ݳ�accu_tempд��HILO
            // ������ˮ����ͣʹ��EX/MEM����NOP��ȡ����֮ͣ����������accu_temp
        end else if(aluop_i == `ALU_OP_MTHI) begin
            we_hilo_o <= `WriteEnable;
            hi_o <= reg1_i;
            lo_o <= LO;
        end else if(aluop_i == `ALU_OP_MTLO) begin
            we_hilo_o <= `WriteEnable;
            hi_o <= HI;
            lo_o <= reg1_i;
        end else begin
            we_hilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end                
    end

    // �����ƶ���дCP0���֣�ֻ�漰MTC0ָ��
    always @ (*) begin
        if (rst == `RstEnable) begin
            cp0_waddr_o <= 8'b00000000;
            cp0_we_o <= `WriteDisable;
            cp0_wdata_o <= `ZeroWord;
        end else if (aluop_i == `ALU_OP_MTC0) begin
            cp0_waddr_o <= cp0_addr;
            cp0_we_o <= `WriteEnable;
            cp0_wdata_o <= reg1_i;
        end else begin
            cp0_waddr_o <= 8'b00000000;
            cp0_we_o <= `WriteDisable;
            cp0_wdata_o <= `ZeroWord;
        end
    end

    // ������������ѡ��һ��������
    always @ (*) begin
        // ����д����ź�
        waddr_o <= waddr_i;
        // ���з�����������������ο�MIPSָ��ֲᣩ
        if((aluop_i == `ALU_OP_ADD || aluop_i == `ALU_OP_SUB) && sum_overflow) begin
            // ��������ֹд + ��������/�쳣
            we_o <= `WriteDisable;
            overflow_occured <= `True_v;
        end else begin
            we_o <= we_i;
            overflow_occured <= `False_v;
        end
        case (alusel_i) 
            `ALU_SEL_LOGIC: begin
                wdata_o <= logic_result;
            end
            `ALU_SEL_SHIFT: begin
                wdata_o <= shift_result;
            end   
            `ALU_SEL_MOVE: begin
                wdata_o <= move_result;
            end   
            `ALU_SEL_ARITHMETIC: begin
                wdata_o <= arithmetic_result;
            end   
            `ALU_SEL_JUMP_BRANCH: begin
                // д�����ַ��ʵ���Ƿ�д��ID������we_o����
                wdata_o <= link_address_i;
            end
            `ALU_SEL_MUL: begin
                // д�Ĵ����ĳ˷�
                wdata_o <= mult_result_i[31:0];
            end
            default: begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end
endmodule
