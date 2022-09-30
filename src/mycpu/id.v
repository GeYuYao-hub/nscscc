//////////////////////////////////////////////////////////////////////////////////
// ����ģ��
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module id(
    input wire clk,
    input wire rst,

    // Լ��_i��β�ı���������
    input wire[`RegBus] pc_i,
    output wire[`RegBus] pc_o,
    input wire[`RegBus] inst_i,
    
    // ����ָ���EX������EX����ô�ָ��ĵ�ַ
    output wire[`RegBus] inst_o,

    // ��regfile�Ŀ����ź�
    output reg re1_o,
    output reg[`RegAddrBus] raddr1_o,
    input wire[`RegBus] rdata1_i,

    output reg re2_o,
    output reg[`RegAddrBus] raddr2_o,
    input wire[`RegBus] rdata2_i,

    //����ִ�н׶εķ����������������ָ���д���
    input wire ex_we_i,
    input wire[`RegBus] ex_wdata_i,
    input wire[`RegAddrBus] ex_waddr_i,
    // �鿴EX�׶εĲ��������EX�Ƿô�״̬����ô�ش���������Ч
    // ��Ϊ�ô�ָ����MEM�׶βŻ�ȡ���ݣ��������Ҫ��ͣһ����ˮ��
    // ʹ��һ��ָ���н���MEM�׶Σ���ʱ���MEM���ӳ٣�MEM�������ͣ��ˮ��
    // �Ӷ���֤��ˮ�߻ظ�ʱMEM���ص���������Ч��
    // ID����ֻ��Ҫ��һ�Ľ���һ��ָ���EX����MEM�Ϳ�����
    input wire[`AluOpBus] ex_aluop_i,

    //���Էô�׶εķ�����������һ��ָ���д���
    input wire mem_we_i,
    input wire[`RegBus] mem_wdata_i,
    input wire[`RegAddrBus] mem_waddr_i,

    // ID/EX����ָʾ��ǰָ���Ƿ����ӳٲ���
    input wire is_in_delayslot_i,
    // branch likelyָ���Ƿ���Ч���ӳٲ�
    input wire is_nullified_i,

    // ��ʶ��һ��ָ���Ƿ����ӳٲ���
    output reg next_inst_in_delayslot_o,
    // ��ʶ��һ��ָ�branch likely��Ч��
    output reg next_inst_is_nullified_o,

    // �����ķ�֧��ת�ź�
    output reg is_branch_o,
    // ��ת�ľ��Ե�ַ
    output reg[`RegBus] branch_target_address_o,       
    // Ҫ����ķ��ص�ַ
    output reg[`RegBus] link_addr_o,
    // ����EX��ǰָ���Ƿ����ӳٲ���
    output reg is_in_delayslot_o,

    // �쳣
    input wire[31:0] exceptions_i,
    output wire[31:0] exceptions_o,

    // ִ�н׶������ź�
    output reg[`AluOpBus] aluop_o,
    output reg[`AluSelBus] alusel_o,
    output reg[`RegBus] reg1_data_o,
    output reg[`RegBus] reg2_data_o,
    // д�Ĵ����׶���Ҫ��ִ����Ϻ�д�ؽ׶���ɣ�����ǰ�׶�Ӧ����дĿ�����Ϣ
    output reg we_o,
    output reg[`RegAddrBus] waddr_o,

    output wire stallreq
    );

    // �м�ָ�EXͨ��ָ�������ڴ��ַ
    assign inst_o = inst_i;
    assign pc_o = pc_i;

    // opcode
    wire[5:0] opcode = inst_i[31:26];
    // R��I
    wire[4:0] rs = inst_i[25:21];
    wire[4:0] rt = inst_i[20:16];
    // R
    wire[4:0] rd = inst_i[15:11];
    wire[4:0] sa = inst_i[10:6];
    wire[5:0] func = inst_i[5:0];
    // �з�����չ������
    wire[`RegBus] signed_imm = {{16{inst_i[15]}}, inst_i[15:0]};
    wire[`RegBus] unsigned_imm = {16'h0, inst_i[15:0]};
    // ������Ҫ������������Ϊ�м�����������������֮������
    reg[`RegBus] imm;
    // ָ����Ч��־λ
    reg inst_valid;

    // �쳣�ź�
    reg exception_is_break;
    reg exception_is_syscall;
    reg exception_is_eret;
    // ��ȷ���壺����λ�ֱ���ϵͳ���á��ϵ㡢ERET��ָ����Ч��ȡָδ����
    assign exceptions_o = {27'd0, exception_is_syscall, exception_is_break, exception_is_eret, inst_valid, exceptions_i[0]};


    // �����֧��ת��ص�����
    // PC��һ��ָ���������ָ��ĵ�ַ���������ڱ��淵�ص�ַ
    wire[`RegBus] pc_next = pc_i + 4;
    wire[`RegBus] pc_next_2 = pc_i + 8;
    // ���ڵ�ַ����������������λ���з�����չ��32λ
    wire[`RegBus] addr_offset_imm = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
    wire[`RegBus] b_addr_imm = {pc_next[31:28], inst_i[25:0], 2'b00};

    // ��ͣ��ˮ�ߵ�����
    // �����Ĵ�����LOAD���״̬
    reg stallreq_for_reg1_loadrelated;
    reg stallreq_for_reg2_loadrelated;
    // ��һ��ָ���Ƿ�Ϊ������ָ��
    wire pre_inst_is_load = ( (ex_aluop_i == `MEM_OP_LB) || 
                                (ex_aluop_i == `MEM_OP_LBU)||
                                (ex_aluop_i == `MEM_OP_LH) ||
                                (ex_aluop_i == `MEM_OP_LHU)||
                                (ex_aluop_i == `MEM_OP_LW) ||
                                (ex_aluop_i == `MEM_OP_LWR)||
                                (ex_aluop_i == `MEM_OP_LWL)||
                                (ex_aluop_i == `MEM_OP_LL) ||
                                (ex_aluop_i == `MEM_OP_SC)) ? 1'b1 : 1'b0;
    // ����stallreq������һ����ͣ������Ч������CTRL������ͣ����
    assign stallreq = stallreq_for_reg1_loadrelated | stallreq_for_reg2_loadrelated;


    // �������������У���Ϊ����������߼���·
    // ���벢��ȡ������������regfile�����źţ�
    always @ (*) begin    
        // ��������
        aluop_o <= `ALU_OP_NOP;
        alusel_o <= `ALU_SEL_NOP;
        we_o <= `WriteDisable;
        re1_o <= `ReadDisable;
        re2_o <= `ReadDisable;
        link_addr_o <= `ZeroWord;
        branch_target_address_o <= `ZeroWord;
        is_branch_o <= `False_v;
        next_inst_in_delayslot_o <= `False_v;
        next_inst_is_nullified_o <= `False_v;
        exception_is_break <= `False_v;
        exception_is_syscall <= `False_v;
        exception_is_eret <= `False_v;
        if (rst == `RstEnable || is_nullified_i) begin
            // ��λ
            waddr_o <= `NOPRegAddr;
            inst_valid <= `InstValid;
            raddr1_o <= `NOPRegAddr;
            raddr2_o <= `NOPRegAddr;
        end else begin
            // ��ʼ��������
            waddr_o <= rd;
            inst_valid <= `InstInvalid;
            raddr1_o <= rs;
            raddr2_o <= rt;
            imm <= `ZeroWord;
            // ����OPCODE����
            case (opcode)
                `OP_SPECIAL: begin
                    if (sa == 5'b00000) begin
                        case (func)
                            // OR
                            `FUNC_OR: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_OR;
                                alusel_o <= `ALU_SEL_LOGIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // AND
                            `FUNC_AND: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_AND;
                                alusel_o <= `ALU_SEL_LOGIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // XOR
                            `FUNC_XOR: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_XOR;
                                alusel_o <= `ALU_SEL_LOGIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // NOR
                            `FUNC_NOR: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_NOR;
                                alusel_o <= `ALU_SEL_LOGIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end 
                            // SLLV
                            `FUNC_SLLV: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SLL;
                                alusel_o <= `ALU_SEL_SHIFT;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end 
                            // SRLV
                            `FUNC_SRLV: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SRL;
                                alusel_o <= `ALU_SEL_SHIFT;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // SRAV                 
                            `FUNC_SRAV: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SRA;
                                alusel_o <= `ALU_SEL_SHIFT;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MFHI               
                            `FUNC_MFHI: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_MFHI;
                                alusel_o <= `ALU_SEL_MOVE;
                                inst_valid <= `InstValid;
                            end
                            // MTHI
                            `FUNC_MTHI: begin
                                aluop_o <= `ALU_OP_MTHI;
                                re1_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MFLO
                            `FUNC_MFLO: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_MFLO;
                                alusel_o <= `ALU_SEL_MOVE;
                                inst_valid <= `InstValid;
                            end
                            // MTLO
                            `FUNC_MTLO: begin
                                aluop_o <= `ALU_OP_MTLO;
                                re1_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // ADD
                            `FUNC_ADD: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_ADD;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // ADDU
                            `FUNC_ADDU: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_ADDU;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // SUB
                            `FUNC_SUB: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SUB;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // SUBU
                            `FUNC_SUBU: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SUBU;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // SLT
                            `FUNC_SLT: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SLT;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // SLTU
                            `FUNC_SLTU: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SLTU;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MULT
                            // �˳�����д��RegFile����˺���EX��Ӧ�����wdata
                            // �����ﱣ��ALU_SEL Ϊ NOP�Խ������
                            `FUNC_MULT: begin
                                aluop_o <= `ALU_OP_MULT;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MULTU
                            `FUNC_MULTU: begin
                                aluop_o <= `ALU_OP_MULTU;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // DIV
                            `FUNC_DIV: begin
                                aluop_o <= `ALU_OP_DIV;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // DIVU
                            `FUNC_DIVU: begin
                                aluop_o <= `ALU_OP_DIVU;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // JR
                            `FUNC_JR: begin
                                alusel_o <= `ALU_SEL_JUMP_BRANCH;
                                re1_o <= `ReadEnable;
                                link_addr_o <= `ZeroWord;
                                branch_target_address_o <= reg1_data_o;
                                is_branch_o <= `True_v;
                                next_inst_in_delayslot_o <= `True_v;
                                inst_valid <= `InstValid;
                            end
                            // JALR
                            `FUNC_JALR: begin
                                we_o <= `WriteEnable;
                                alusel_o <= `ALU_SEL_JUMP_BRANCH;
                                re1_o <= `ReadEnable;
                                link_addr_o <= pc_next_2;
                                branch_target_address_o <= reg1_data_o;
                                is_branch_o <= `True_v;
                                next_inst_in_delayslot_o <= `True_v;
                                inst_valid <= `InstValid;
                            end
                            // MOVN               
                            `FUNC_MOVN: begin
                                aluop_o <= `ALU_OP_MOV;
                                alusel_o <= `ALU_SEL_MOVE;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                                we_o <= (reg2_data_o != `ZeroWord);
                            end 
                            // MOVZ              
                            `FUNC_MOVZ: begin
                                aluop_o <= `ALU_OP_MOV;
                                alusel_o <= `ALU_SEL_MOVE;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                                we_o <= (reg2_data_o == `ZeroWord);
                            end
                            default: begin
                            end
                        // END FOR CASE func code
                        endcase
                    // END FOR SA 000000
                    end else begin    
                    end 
                    if (rs == 5'h00000) begin 
                        case (func)
                            // SLL
                            `FUNC_SLL: begin
                                waddr_o <= rd;
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SLL;
                                alusel_o <= `ALU_SEL_SHIFT;
                                re2_o <= `ReadEnable;
                                imm[4:0] <= sa;
                                inst_valid <= `InstValid;
                            end
                            // SRL
                            `FUNC_SRL: begin
                                waddr_o <= rd;
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SRL;
                                alusel_o <= `ALU_SEL_SHIFT;
                                re2_o <= `ReadEnable;
                                imm[4:0] <= sa;
                                inst_valid <= `InstValid;
                            end 
                            // SRA
                            `FUNC_SRA: begin
                                waddr_o <= rd;
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_SRA;
                                alusel_o <= `ALU_SEL_SHIFT;
                                re2_o <= `ReadEnable;
                                imm[4:0] <= sa;
                                inst_valid <= `InstValid;
                            end           
                            default: begin
                            end
                        // END FOR CASE func code
                        endcase
                    // END FOR rs 000000
                    end else begin
                    end
                    // just func code
                    case (func)
                        // TEQ
                        `FUNC_TEQ: begin
                            aluop_o <= `ALU_OP_TEQ;
                            inst_valid <= `InstValid;
                        end
                        // TGE
                        `FUNC_TGE: begin
                            aluop_o <= `ALU_OP_TGE;
                            re1_o <= `ReadEnable;
                            re2_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                        end 
                        // TGEU     
                        `FUNC_TGEU: begin
                            aluop_o <= `ALU_OP_TGEU;
                            re1_o <= `ReadEnable;
                            re2_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                        end
                        // TLT
                        `FUNC_TLT: begin
                            aluop_o <= `ALU_OP_TLT;
                            re1_o <= `ReadEnable;
                            re2_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                        end
                        // TLTU
                        `FUNC_TLTU: begin
                            aluop_o <= `ALU_OP_TLTU;
                            re1_o <= `ReadEnable;
                            re2_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                        end
                        // TNE
                        `FUNC_TNE: begin
                            aluop_o <= `ALU_OP_TNE;
                            re1_o <= `ReadEnable;
                            re2_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                        end
                        // SYSCALL
                        `FUNC_SYSCALL: begin
                            inst_valid <= `InstValid;
                            exception_is_syscall <= `True_v;
                        end
                        // BREAK
                        `FUNC_BREAK: begin
                            inst_valid <= `InstValid;
                            exception_is_break <= `True_v;
                        end
                        default: begin
                        end
                    endcase
                end // END FOR OPCODE SPECIAL
                `OP_SPECIAL2: begin
                    if (sa == 5'b00000) begin
                        case (func)
                            // CLZ
                            `FUNC_CLZ: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_CLZ;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // CLO
                            `FUNC_CLO: begin
                                we_o <= `WriteEnable;
                                aluop_o <= `ALU_OP_CLO;
                                alusel_o <= `ALU_SEL_ARITHMETIC;
                                re1_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MUL
                            `FUNC_MUL: begin
                                // ����˷���д��HILO������д��GPR������Ҫ��дʹ��
                                we_o <= `WriteEnable;
                                // ʹ�ó˷�����õ��˷����
                                aluop_o <= `ALU_OP_MUL;
                                // ���������������⣺��ͨ�˷�д��HILO�����ﲻ��
                                alusel_o <= `ALU_SEL_MUL;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MADD
                            `FUNC_MADD: begin
                                aluop_o <= `ALU_OP_MADD;
                                alusel_o <= `ALU_SEL_MUL;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MADDU
                            `FUNC_MADDU: begin
                                aluop_o <= `ALU_OP_MADDU;
                                alusel_o <= `ALU_SEL_MUL;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MSUB
                            `FUNC_MSUB: begin
                                aluop_o <= `ALU_OP_MSUB;
                                alusel_o <= `ALU_SEL_MUL;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            // MSUBU
                            `FUNC_MSUBU: begin
                                aluop_o <= `ALU_OP_MSUBU;
                                alusel_o <= `ALU_SEL_MUL;
                                re1_o <= `ReadEnable;
                                re2_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                            end
                            default: begin
                            end
                        // END FOR CASE func code
                        endcase
                    // END FOR SA 000000
                    end begin 
                    end
                end // END FOR OPCODE SPECIAL2
                `OP_REGIMM: begin
                    case(rt)
                        // BLTZ
                        `RT_BLTZ: begin
                            alusel_o <= `ALU_SEL_JUMP_BRANCH;
                            re1_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                            if(reg1_data_o[31]) begin
                                branch_target_address_o <= pc_next + addr_offset_imm;
                                is_branch_o <= `True_v;
                           end
                            next_inst_in_delayslot_o <= `True_v;
                        end
                        // BLTZL
                        `RT_BLTZL: begin
                            alusel_o <= `ALU_SEL_JUMP_BRANCH;
                            re1_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                            if(reg1_data_o[31]) begin
                                branch_target_address_o <= pc_next + addr_offset_imm;
                                is_branch_o <= `True_v;
                                next_inst_in_delayslot_o <= `True_v;
                            end else begin
                                next_inst_is_nullified_o <= `True_v;
                            end
                        end
                        // BGEZ
                        `RT_BGEZ: begin
                            alusel_o <= `ALU_SEL_JUMP_BRANCH;
                            re1_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                            if(!reg1_data_o[31]) begin
                                branch_target_address_o <= pc_next + addr_offset_imm;
                                is_branch_o <= `True_v;
                            end
                            next_inst_in_delayslot_o <= `True_v;
                        end
                        // BGEZL
                        `RT_BGEZL: begin
                            if (rt == 5'b00000) begin
                                alusel_o <= `ALU_SEL_JUMP_BRANCH;
                                re1_o <= `ReadEnable;
                                inst_valid <= `InstValid;
                                if(!reg1_data_o[31]) begin
                                    branch_target_address_o <= pc_next + addr_offset_imm;
                                    is_branch_o <= `True_v;
                                    next_inst_in_delayslot_o <= `True_v;
                                end else begin
                                    next_inst_is_nullified_o <= `True_v;
                                end
                            end else begin
                            end
                        end
                        // BLTZAL
                        `RT_BLTZAL: begin    
                            waddr_o <= 5'b11111;
                            we_o <= `WriteEnable;
                            alusel_o <= `ALU_SEL_JUMP_BRANCH;
                            re1_o <= `ReadEnable;
                            link_addr_o <= pc_next_2;
                            inst_valid <= `InstValid;
                            next_inst_in_delayslot_o <= `True_v;    
                            if(reg1_data_o[31]) begin
                                branch_target_address_o <= pc_next + addr_offset_imm;
                                is_branch_o <= `True_v;
                            end
                        end
                        // BLTZALL
                        `RT_BLTZALL: begin    
                            waddr_o <= 5'b11111;
                            we_o <= `WriteEnable;
                            alusel_o <= `ALU_SEL_JUMP_BRANCH;
                            re1_o <= `ReadEnable;
                            link_addr_o <= pc_next_2;
                            inst_valid <= `InstValid;
                            if(reg1_data_o[31]) begin
                                branch_target_address_o <= pc_next + addr_offset_imm;
                                is_branch_o <= `True_v;
                                next_inst_in_delayslot_o <= `True_v;
                            end else begin
                                next_inst_is_nullified_o <= `True_v;
                            end
                        end
                        // BGEZAL
                        `RT_BGEZAL: begin 
                            waddr_o <= 5'b11111;
                            we_o <= `WriteEnable;
                            alusel_o <= `ALU_SEL_JUMP_BRANCH;
                            re1_o <= `ReadEnable;
                            link_addr_o <= pc_next_2;
                            inst_valid <= `InstValid;
                            next_inst_in_delayslot_o <= `True_v;
                            if(!reg1_data_o[31]) begin
                                branch_target_address_o <= pc_next + addr_offset_imm;
                                is_branch_o <= `True_v;
                            end
                        end
                        // BGEZALL
                        `RT_BGEZALL: begin 
                            waddr_o <= 5'b11111;
                            we_o <= `WriteEnable;
                            alusel_o <= `ALU_SEL_JUMP_BRANCH;
                            re1_o <= `ReadEnable;
                            link_addr_o <= pc_next_2;
                            inst_valid <= `InstValid;
                            if(!reg1_data_o[31]) begin
                                branch_target_address_o <= pc_next + addr_offset_imm;
                                is_branch_o <= `True_v;
                                next_inst_in_delayslot_o <= `True_v;
                            end else begin
                                next_inst_is_nullified_o <= `True_v;
                            end
                        end
                        // TEQI
                        `RT_TEQI: begin
                            we_o <= `WriteDisable;
                            aluop_o <= `ALU_OP_TEQ;
                            re1_o <= `ReadEnable;       
                            imm <= signed_imm;              
                            inst_valid <= `InstValid;    
                        end
                        // TGEI
                        `RT_TGEI: begin
                            we_o <= `WriteDisable;
                            aluop_o <= `ALU_OP_TGE;
                            re1_o <= `ReadEnable;        
                            imm <= signed_imm;              
                            inst_valid <= `InstValid;    
                        end
                        // TGEIU
                        `RT_TGEIU: begin
                            we_o <= `WriteDisable;
                            aluop_o <= `ALU_OP_TGEU;
                            re1_o <= `ReadEnable;        
                            imm <= signed_imm;              
                            inst_valid <= `InstValid;    
                        end
                        // TLTI
                        `RT_TLTI: begin
                            we_o <= `WriteDisable;
                            aluop_o <= `ALU_OP_TLT;
                            re1_o <= `ReadEnable;         
                            imm <= signed_imm;              
                            inst_valid <= `InstValid;    
                        end
                        // TLTIU
                        `RT_TLTIU: begin
                            we_o <= `WriteDisable;
                            aluop_o <= `ALU_OP_TLTU;
                            re1_o <= `ReadEnable;       
                            imm <= signed_imm;              
                            inst_valid <= `InstValid;    
                        end
                        // TNEI
                        `RT_TNEI: begin
                            we_o <= `WriteDisable;
                            aluop_o <= `ALU_OP_TNE;
                            re1_o <= `ReadEnable;    
                            imm <= signed_imm;              
                            inst_valid <= `InstValid;    
                        end
                        default: begin
                        end
                    // END FOR CASE rt
                    endcase
                end // END FOR OPCODE REGIMM
                `OP_COP0: begin
                    case (rs)
                        // MFC0
                        `CP0_RS_MF: begin
                            waddr_o <= rt;
                            we_o <= `WriteEnable;
                            aluop_o <= `ALU_OP_MFC0;
                            alusel_o <= `ALU_SEL_MOVE;
                            inst_valid <= `InstValid;
                        end 
                        // MTC0
                        `CP0_RS_MT: begin
                            aluop_o <= `ALU_OP_MTC0;
                            alusel_o <= `ALU_SEL_MOVE;
                            raddr1_o <= rt;
                            re1_o <= `ReadEnable;
                            inst_valid <= `InstValid;
                        end 
                        // CO = 1����Ҫ��һ���ж�FUNC
                        `CP0_RS_CO: begin
                            case (func)
                                // ERET
                                `FUNC_ERET: begin
                                    inst_valid <= `InstValid; 
                                    exception_is_eret <= `True_v;
                                end 
                                default: begin
                                end
                            endcase
                        end 
                        default: begin
                            // do nothing
                        end
                    endcase
                end // END FOR OPCODE COP0
                // ORI
                `OP_ORI: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_OR;
                    alusel_o <= `ALU_SEL_LOGIC;
                    re1_o <= `ReadEnable;
                    imm <= unsigned_imm;
                    inst_valid <= `InstValid;
                end
                // ANDI
                `OP_ANDI: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_AND;
                    alusel_o <= `ALU_SEL_LOGIC;
                    re1_o <= `ReadEnable;
                    imm <= unsigned_imm;
                    inst_valid <= `InstValid;
                end
                // XORI
                `OP_XORI: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_XOR;
                    alusel_o <= `ALU_SEL_LOGIC;
                    re1_o <= `ReadEnable;
                    imm <= unsigned_imm;
                    inst_valid <= `InstValid;
                end
                // LUI
                `OP_LUI: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_OR;
                    alusel_o <= `ALU_SEL_LOGIC;
                    re1_o <= `ReadEnable;
                    imm <= {inst_i[15:0], 16'h0};
                    inst_valid <= `InstValid;
                end
                // ADDI
                `OP_ADDI: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_ADD;
                    alusel_o <= `ALU_SEL_ARITHMETIC;
                    re1_o <= `ReadEnable;
                    imm <= signed_imm;
                    inst_valid <= `InstValid;
                end
                // ADDIU
                `OP_ADDIU: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_ADDU;
                    alusel_o <= `ALU_SEL_ARITHMETIC;
                    re1_o <= `ReadEnable;
                    imm <= signed_imm;
                    inst_valid <= `InstValid;
                end
                // SLTI
                `OP_SLTI: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_SLT;
                    alusel_o <= `ALU_SEL_ARITHMETIC;
                    re1_o <= `ReadEnable;
                    imm <= signed_imm;
                    inst_valid <= `InstValid;
                end
                // SLTIU
                `OP_SLTIU: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `ALU_OP_SLTU;
                    alusel_o <= `ALU_SEL_ARITHMETIC;
                    re1_o <= `ReadEnable;
                    imm <= signed_imm;
                    inst_valid <= `InstValid;
                end
                // J
                `OP_J: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    link_addr_o <= `ZeroWord;
                    branch_target_address_o <= b_addr_imm;
                    is_branch_o <= `True_v;
                    next_inst_in_delayslot_o <= `True_v;
                    inst_valid <= `InstValid;
                end
                // JAL
                `OP_JAL: begin
                    // �̶�д��$31��Ϊ���ص�ַ  
                    waddr_o <= 5'b11111;
                    we_o <= `WriteEnable;
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    link_addr_o <= pc_next_2 ;
                    branch_target_address_o <= b_addr_imm;
                    is_branch_o <= `True_v;
                    next_inst_in_delayslot_o <= `True_v;
                    inst_valid <= `InstValid;
                end
                // BEQ
                `OP_BEQ: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                    if(reg1_data_o == reg2_data_o) begin
                        branch_target_address_o <= pc_next + addr_offset_imm;
                        is_branch_o <= `True_v;
                    end
                    next_inst_in_delayslot_o <= `True_v;
                end
                // BEQL
                `OP_BEQL: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                    if(reg1_data_o == reg2_data_o) begin
                        branch_target_address_o <= pc_next + addr_offset_imm;
                        is_branch_o <= `True_v;
                        next_inst_in_delayslot_o <= `True_v;
                    end else begin
                        // ������ת����Ч���ӳٲ�
                        next_inst_is_nullified_o <= `True_v;
                    end
                end
                // BNE
                `OP_BNE: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                    if(reg1_data_o != reg2_data_o) begin
                        branch_target_address_o <= pc_next + addr_offset_imm;
                        is_branch_o <= `True_v;
                    end
                    next_inst_in_delayslot_o <= `True_v;
                end
                // BNEL
                `OP_BNEL: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                    if(reg1_data_o != reg2_data_o) begin
                        branch_target_address_o <= pc_next + addr_offset_imm;
                        is_branch_o <= `True_v;
                        next_inst_in_delayslot_o <= `True_v;
                    end else begin
                        next_inst_is_nullified_o <= `True_v;
                    end
                end
                // BGTZ
                `OP_BGTZ: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                    if(!reg1_data_o[31] && reg1_data_o != `ZeroWord) begin
                        branch_target_address_o <= pc_next + addr_offset_imm;
                        is_branch_o <= `True_v;
                    end
                    next_inst_in_delayslot_o <= `True_v;
                end
                // BGTZL
                `OP_BGTZL: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                    if(!reg1_data_o[31] && reg1_data_o != `ZeroWord) begin
                        branch_target_address_o <= pc_next + addr_offset_imm;
                        is_branch_o <= `True_v;
                        next_inst_in_delayslot_o <= `True_v;
                    end else begin
                       next_inst_is_nullified_o <= `True_v;
                    end
                end
                // BLEZ
                `OP_BLEZ: begin
                    alusel_o <= `ALU_SEL_JUMP_BRANCH;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                    if(reg1_data_o[31] || reg1_data_o == `ZeroWord) begin
                        branch_target_address_o <= pc_next + addr_offset_imm;
                        is_branch_o <= `True_v;
                    end
                    next_inst_in_delayslot_o <= `True_v;
                end
                // BLEZL
                `OP_BLEZL: begin
                    if (rt == 5'b00000) begin
                        alusel_o <= `ALU_SEL_JUMP_BRANCH;
                        re1_o <= `ReadEnable;
                        inst_valid <= `InstValid;
                        if(reg1_data_o[31] || reg1_data_o == `ZeroWord) begin
                            branch_target_address_o <= pc_next + addr_offset_imm;
                            is_branch_o <= `True_v;
                            next_inst_in_delayslot_o <= `True_v;
                        end else begin
                            next_inst_is_nullified_o <= `True_v;
                        end
                    end else begin
                    end
                end
                // LB
                `OP_LB: begin         
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LB;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;// base
                    inst_valid <= `InstValid;
                end
                // LH
                `OP_LH: begin         
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LH;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // LWL
                `OP_LWL: begin         
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LWL;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // LW
                `OP_LW: begin          
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LW;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // LBU
                `OP_LBU: begin        
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LBU;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // LHU
                `OP_LHU: begin        
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LHU;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // LWR
                `OP_LWR: begin
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LWR;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // SB
                `OP_SB: begin
                    aluop_o <= `MEM_OP_SB;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // SH
                `OP_SH: begin
                    aluop_o <= `MEM_OP_SH;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // SWL
                `OP_SWL: begin
                    aluop_o <= `MEM_OP_SWL;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // SWR
                `OP_SWR: begin
                    aluop_o <= `MEM_OP_SWR;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // SW
                `OP_SW: begin
                    aluop_o <= `MEM_OP_SW;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // LL
                `OP_LL: begin          
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_LL;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                // SC
                `OP_SC: begin         
                    waddr_o <= rt;
                    we_o <= `WriteEnable;
                    aluop_o <= `MEM_OP_SC;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    alusel_o <= `ALU_SEL_LOAD_STORE;
                    re1_o <= `ReadEnable;
                    re2_o <= `ReadEnable;
                    inst_valid <= `InstValid;
                end
                default: begin
                end
            // END FOR CASE OPCODE
            endcase
        end
    end

    // �����ӳٲ��ź�
    always @ (*) begin
        if(rst == `RstEnable) begin
            is_in_delayslot_o <= `False_v;
        end else begin
            is_in_delayslot_o <= is_in_delayslot_i;
        end
    end
    
    // �����һ��������
    always @ (*) begin
        // һ������Ҫ��������������ΪֻҪ��ͣһ��
        stallreq_for_reg1_loadrelated <= `NoStop;
        if(rst == `RstEnable) begin
            reg1_data_o <= `ZeroWord;
        // ���������һ���Ǽ���ָ���Ҽ��ص�Ŀ��Ĵ������Ƕ˿�1��ȡ��
        // ��ô��������ͣ��ˮ���Խ��LOAD���
        end else if(pre_inst_is_load && ex_waddr_i == raddr1_o && re1_o == `ReadEnable ) begin
            stallreq_for_reg1_loadrelated <= `Stop;
        end else if(re1_o == `ReadEnable && ex_we_i == `WriteEnable && ex_waddr_i == raddr1_o) begin
            // �˿�1���������������ִ�н׶Σ��ȷô�׶��£������Ľ�д�������
            reg1_data_o <= ex_wdata_i;
        end else if(re1_o == `ReadEnable && mem_we_i == `WriteEnable && mem_waddr_i == raddr1_o) begin
            // �˿�1��������������Ƿô�׶Σ��ȼĴ������£������Ľ�д������
            reg1_data_o <= mem_wdata_i;
        end else if(re1_o == `ReadEnable) begin
            // ���˿�1
            reg1_data_o <= rdata1_i;
        end else if(re1_o == `ReadDisable) begin
            // ����˿�1����Ҫ�������ø�������
            // Ŀǰ��˵�˿�1������ζ���Ҫ���ģ�rs��
            // ����дֻ��Ϊ����˿�2�ȽϹ���
            reg1_data_o <= imm;
        end else begin
            // һ�㲻�������������������걸��if..else if..else����ۺϺ����Ч
            reg1_data_o <= `ZeroWord;
        end
    end

    // ͬ�ϣ�����ڶ������������ڶ���������������Դ��������
    always @ (*) begin
        // һ������Ҫ��������������ΪֻҪ��ͣһ��
        stallreq_for_reg2_loadrelated <= `NoStop;
        if(rst == `RstEnable) begin
            reg2_data_o <= `ZeroWord;
        // ���������һ���Ǽ���ָ���Ҽ��ص�Ŀ��Ĵ������Ƕ˿�2��ȡ��
        // ��ô��������ͣ��ˮ���Խ��LOAD���
        end else if(pre_inst_is_load && ex_waddr_i == raddr2_o && re2_o == `ReadEnable ) begin
            stallreq_for_reg2_loadrelated <= `Stop;
        end else if(re2_o == `ReadEnable && ex_we_i == `WriteEnable && ex_waddr_i == raddr2_o) begin
            // �˿�2���������������ִ�н׶Σ��ȷô�׶��£������Ľ�д�������
            reg2_data_o <= ex_wdata_i;
        end else if(re2_o == `ReadEnable && mem_we_i == `WriteEnable && mem_waddr_i == raddr2_o) begin
            // �˿�2��������������Ƿô�׶Σ��ȼĴ������£������Ľ�д������
            reg2_data_o <= mem_wdata_i;
        end else if(re2_o == `ReadEnable) begin
            // ���˿�2
            reg2_data_o <= rdata2_i;
        end else if(re2_o == `ReadDisable) begin
            // ����˿�2����Ҫ�������ø�������
            reg2_data_o <= imm;
        end else begin
            // һ�㲻�������������������걸��if..else if..else����ۺϺ����Ч
            reg2_data_o <= `ZeroWord;
        end
    end

endmodule
