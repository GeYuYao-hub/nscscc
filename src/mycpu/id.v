//////////////////////////////////////////////////////////////////////////////////
// 译码模块
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module id(
    input wire clk,
    input wire rst,

    // 约定_i结尾的变量是输入
    input wire[`RegBus] pc_i,
    output wire[`RegBus] pc_o,
    input wire[`RegBus] inst_i,
    
    // 传递指令给EX，便于EX计算访存指令的地址
    output wire[`RegBus] inst_o,

    // 读regfile的控制信号
    output reg re1_o,
    output reg[`RegAddrBus] raddr1_o,
    input wire[`RegBus] rdata1_i,

    output reg re2_o,
    output reg[`RegAddrBus] raddr2_o,
    input wire[`RegBus] rdata2_i,

    //来自执行阶段的反馈，解决相邻两条指令的写后读
    input wire ex_we_i,
    input wire[`RegBus] ex_wdata_i,
    input wire[`RegAddrBus] ex_waddr_i,
    // 查看EX阶段的操作，如果EX是访存状态，那么回传的数据无效
    // 因为访存指令在MEM阶段才获取数据，因此这里要暂停一拍流水线
    // 使上一条指令行进到MEM阶段，这时如果MEM有延迟，MEM会提出暂停流水线
    // 从而保证流水线回复时MEM返回的数据是有效的
    // ID这里只需要空一拍将上一条指令从EX送入MEM就可以了
    input wire[`AluOpBus] ex_aluop_i,

    //来自访存阶段的反馈，解决相隔一条指令的写后读
    input wire mem_we_i,
    input wire[`RegBus] mem_wdata_i,
    input wire[`RegAddrBus] mem_waddr_i,

    // ID/EX反馈指示当前指令是否在延迟槽内
    input wire is_in_delayslot_i,
    // branch likely指令是否无效化延迟槽
    input wire is_nullified_i,

    // 标识下一条指令是否在延迟槽内
    output reg next_inst_in_delayslot_o,
    // 标识下一条指令被branch likely无效化
    output reg next_inst_is_nullified_o,

    // 产生的分支跳转信号
    output reg is_branch_o,
    // 跳转的绝对地址
    output reg[`RegBus] branch_target_address_o,       
    // 要保存的返回地址
    output reg[`RegBus] link_addr_o,
    // 告诉EX当前指令是否在延迟槽内
    output reg is_in_delayslot_o,

    // 异常
    input wire[31:0] exceptions_i,
    output wire[31:0] exceptions_o,

    // 执行阶段所需信号
    output reg[`AluOpBus] aluop_o,
    output reg[`AluSelBus] alusel_o,
    output reg[`RegBus] reg1_data_o,
    output reg[`RegBus] reg2_data_o,
    // 写寄存器阶段需要在执行完毕后写回阶段完成，但当前阶段应产生写目标的信息
    output reg we_o,
    output reg[`RegAddrBus] waddr_o,

    output wire stallreq
    );

    // 中继指令，EX通过指令计算出内存地址
    assign inst_o = inst_i;
    assign pc_o = pc_i;

    // opcode
    wire[5:0] opcode = inst_i[31:26];
    // R、I
    wire[4:0] rs = inst_i[25:21];
    wire[4:0] rt = inst_i[20:16];
    // R
    wire[4:0] rd = inst_i[15:11];
    wire[4:0] sa = inst_i[10:6];
    wire[5:0] func = inst_i[5:0];
    // 有符号扩展立即数
    wire[`RegBus] signed_imm = {{16{inst_i[15]}}, inst_i[15:0]};
    wire[`RegBus] unsigned_imm = {16'h0, inst_i[15:0]};
    // 最终需要的立即数，作为中间变量用于译码与输出之间解耦合
    reg[`RegBus] imm;
    // 指令有效标志位
    reg inst_valid;

    // 异常信号
    reg exception_is_break;
    reg exception_is_syscall;
    reg exception_is_eret;
    // 明确含义：低五位分别是系统调用、断点、ERET、指令无效、取指未对齐
    assign exceptions_o = {27'd0, exception_is_syscall, exception_is_break, exception_is_eret, inst_valid, exceptions_i[0]};


    // 计算分支跳转相关的数据
    // PC下一条指令和下两条指令的地址，后者用于保存返回地址
    wire[`RegBus] pc_next = pc_i + 4;
    wire[`RegBus] pc_next_2 = pc_i + 8;
    // 用于地址的立即数，左移两位并有符号扩展到32位
    wire[`RegBus] addr_offset_imm = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
    wire[`RegBus] b_addr_imm = {pc_next[31:28], inst_i[25:0], 2'b00};

    // 暂停流水线的请求
    // 两个寄存器的LOAD相关状态
    reg stallreq_for_reg1_loadrelated;
    reg stallreq_for_reg2_loadrelated;
    // 上一条指令是否为加载类指令
    wire pre_inst_is_load = ( (ex_aluop_i == `MEM_OP_LB) || 
                                (ex_aluop_i == `MEM_OP_LBU)||
                                (ex_aluop_i == `MEM_OP_LH) ||
                                (ex_aluop_i == `MEM_OP_LHU)||
                                (ex_aluop_i == `MEM_OP_LW) ||
                                (ex_aluop_i == `MEM_OP_LWR)||
                                (ex_aluop_i == `MEM_OP_LWL)||
                                (ex_aluop_i == `MEM_OP_LL) ||
                                (ex_aluop_i == `MEM_OP_SC)) ? 1'b1 : 1'b0;
    // 产生stallreq，任意一种暂停请求生效，都向CTRL发起暂停请求
    assign stallreq = stallreq_for_reg1_loadrelated | stallreq_for_reg2_loadrelated;


    // 对所有输入敏感，因为译码是组合逻辑电路
    // 译码并获取操作数（产生regfile控制信号）
    always @ (*) begin    
        // 公共操作
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
            // 复位
            waddr_o <= `NOPRegAddr;
            inst_valid <= `InstValid;
            raddr1_o <= `NOPRegAddr;
            raddr2_o <= `NOPRegAddr;
        end else begin
            // 开始正常译码
            waddr_o <= rd;
            inst_valid <= `InstInvalid;
            raddr1_o <= rs;
            raddr2_o <= rt;
            imm <= `ZeroWord;
            // 根据OPCODE译码
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
                            // 乘除法不写入RegFile，因此后面EX不应当输出wdata
                            // 故这里保持ALU_SEL 为 NOP以禁用输出
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
                                // 这个乘法不写入HILO，而是写入GPR，所以要打开写使能
                                we_o <= `WriteEnable;
                                // 使用乘法计算得到乘法结果
                                aluop_o <= `ALU_OP_MUL;
                                // 但是运算类型特殊：普通乘法写入HILO，这里不是
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
                        // CO = 1，需要进一步判断FUNC
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
                    // 固定写入$31作为返回地址  
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
                        // 若不跳转则无效化延迟槽
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

    // 处理延迟槽信号
    always @ (*) begin
        if(rst == `RstEnable) begin
            is_in_delayslot_o <= `False_v;
        end else begin
            is_in_delayslot_o <= is_in_delayslot_i;
        end
    end
    
    // 处理第一个操作数
    always @ (*) begin
        // 一上来就要重置相关情况，因为只要暂停一拍
        stallreq_for_reg1_loadrelated <= `NoStop;
        if(rst == `RstEnable) begin
            reg1_data_o <= `ZeroWord;
        // 这里如果上一条是加载指令且加载的目标寄存器就是端口1读取的
        // 那么就申请暂停流水线以解决LOAD相关
        end else if(pre_inst_is_load && ex_waddr_i == raddr1_o && re1_o == `ReadEnable ) begin
            stallreq_for_reg1_loadrelated <= `Stop;
        end else if(re1_o == `ReadEnable && ex_we_i == `WriteEnable && ex_waddr_i == raddr1_o) begin
            // 端口1请求的数据正好是执行阶段（比访存阶段新）产生的将写入的数据
            reg1_data_o <= ex_wdata_i;
        end else if(re1_o == `ReadEnable && mem_we_i == `WriteEnable && mem_waddr_i == raddr1_o) begin
            // 端口1请求的数据正好是访存阶段（比寄存器堆新）产生的将写入数据
            reg1_data_o <= mem_wdata_i;
        end else if(re1_o == `ReadEnable) begin
            // 读端口1
            reg1_data_o <= rdata1_i;
        end else if(re1_o == `ReadDisable) begin
            // 如果端口1不需要读，就用给立即数
            // 目前来说端口1无论如何都是要读的（rs）
            // 这样写只是为了与端口2比较规整
            reg1_data_o <= imm;
        end else begin
            // 一般不会出现这种情况，但是完备的if..else if..else语句综合后更高效
            reg1_data_o <= `ZeroWord;
        end
    end

    // 同上，处理第二个操作数，第二个操作数可能来源于立即数
    always @ (*) begin
        // 一上来就要重置相关情况，因为只要暂停一拍
        stallreq_for_reg2_loadrelated <= `NoStop;
        if(rst == `RstEnable) begin
            reg2_data_o <= `ZeroWord;
        // 这里如果上一条是加载指令且加载的目标寄存器就是端口2读取的
        // 那么就申请暂停流水线以解决LOAD相关
        end else if(pre_inst_is_load && ex_waddr_i == raddr2_o && re2_o == `ReadEnable ) begin
            stallreq_for_reg2_loadrelated <= `Stop;
        end else if(re2_o == `ReadEnable && ex_we_i == `WriteEnable && ex_waddr_i == raddr2_o) begin
            // 端口2请求的数据正好是执行阶段（比访存阶段新）产生的将写入的数据
            reg2_data_o <= ex_wdata_i;
        end else if(re2_o == `ReadEnable && mem_we_i == `WriteEnable && mem_waddr_i == raddr2_o) begin
            // 端口2请求的数据正好是访存阶段（比寄存器堆新）产生的将写入数据
            reg2_data_o <= mem_wdata_i;
        end else if(re2_o == `ReadEnable) begin
            // 读端口2
            reg2_data_o <= rdata2_i;
        end else if(re2_o == `ReadDisable) begin
            // 如果端口2不需要读，就用给立即数
            reg2_data_o <= imm;
        end else begin
            // 一般不会出现这种情况，但是完备的if..else if..else语句综合后更高效
            reg2_data_o <= `ZeroWord;
        end
    end

endmodule
