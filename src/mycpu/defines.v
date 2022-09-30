// Ϊ��ߴ���ɶ���
`define RstEnable 1'b1
`define RstDisable 1'b0
`define ZeroWord 32'h00000000
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0
`define InstValid 1'b0
`define InstInvalid 1'b1
`define Stop 1'b1
`define NoStop 1'b0
`define True_v 1'b1
`define False_v 1'b0
// �˷������������
`define ResultReady 1'b1
`define ResultNotReady 1'b0
`define ComputeStart 1'b1
`define ComputeStop 1'b0

// ͨ�üĴ�����ַ����5λ��Ѱַ32��
`define RegAddrBus 4:0
// ͨ�üĴ�����ַ���
`define RegAddrBusWidth 5
// ͨ�üĴ������ݴ���
`define RegBus 31:0
// ˫���������ڱ���˷����
`define DoubleRegBus 63:0
// ͨ�üĴ�������
`define RegNum 32
// ALU���㷽ʽ����
`define AluOpBus 7:0
// ALU�������ʹ���
`define AluSelBus 2:0

// ������
// �߼����㡢λ������
`define OP_SPECIAL 6'b000000
`define OP_ANDI    6'b001100
`define OP_ORI     6'b001101
`define OP_XORI    6'b001110
`define OP_LUI     6'b001111
// ��������
// ������
`define OP_ADDI      6'b001000
`define OP_ADDIU     6'b001001
`define OP_SLTI      6'b001010
`define OP_SLTIU     6'b001011
// �����ں���������
`define OP_SPECIAL2  6'b011100
// ��֧��ת
`define OP_REGIMM 6'b000001
`define OP_J      6'b000010
`define OP_JAL    6'b000011
`define OP_BEQ    6'b000100
`define OP_BNE    6'b000101
`define OP_BLEZ   6'b000110
`define OP_BGTZ   6'b000111
// Branch likely
`define OP_BEQL  6'b010100
`define OP_BNEL  6'b010101
`define OP_BLEZL 6'b010110
`define OP_BGTZL 6'b010111
// �ô�ָ��
`define OP_LB  6'b100000
`define OP_LH  6'b100001
`define OP_LWL 6'b100010
`define OP_LW  6'b100011
`define OP_LBU 6'b100100
`define OP_LHU 6'b100101
`define OP_LWR 6'b100110
`define OP_SB  6'b101000
`define OP_SH  6'b101001
`define OP_SWL 6'b101010
`define OP_SW  6'b101011
`define OP_SWR 6'b101110
// Read Modify Write�����ָ��
`define OP_LL  6'b110000
`define OP_SC  6'b111000
// Э������ָ��
`define OP_COP0 6'b010000

// RS�Ĵ��������OPΪCOP0ʱ�ж�ָ������
`define CP0_RS_MF 5'b00000
`define CP0_RS_MT 5'b00100
`define CP0_RS_CO 5'b10000 // TLB��ָ�������Ӱ��CP0����

// RT�Ĵ��������OPΪREGIMMʱ�ж���ת����
`define RT_BLTZ    5'b00000
`define RT_BGEZ    5'b00001
`define RT_BLTZL   5'b00010
`define RT_BGEZL   5'b00011
`define RT_TEQI    5'b01100
`define RT_TGEI    5'b01000
`define RT_TGEIU   5'b01001
`define RT_TLTI    5'b01010
`define RT_TLTIU   5'b01011
`define RT_TNEI    5'b01110
`define RT_BLTZAL  5'b10000
`define RT_BGEZAL  5'b10001
`define RT_BLTZALL 5'b10010
`define RT_BGEZALL 5'b10011

// ������
// �߼�����
`define FUNC_AND 6'b100100
`define FUNC_OR  6'b100101
`define FUNC_XOR 6'b100110
`define FUNC_NOR 6'b100111
// λ������
`define FUNC_SLL  6'b000000
`define FUNC_SRL  6'b000010
`define FUNC_SRA  6'b000011
`define FUNC_SLLV 6'b000100
`define FUNC_SRLV 6'b000110
`define FUNC_SRAV 6'b000111
// �����ƶ�
`define FUNC_MOVZ 6'b001010
`define FUNC_MOVN 6'b001011
`define FUNC_MFHI 6'b010000
`define FUNC_MTHI 6'b010001
`define FUNC_MFLO 6'b010010
`define FUNC_MTLO 6'b010011
// ��������������
`define FUNC_ADD   6'b100000
`define FUNC_ADDU  6'b100001
`define FUNC_SUB   6'b100010
`define FUNC_SUBU  6'b100011
`define FUNC_SLT   6'b101010
`define FUNC_SLTU  6'b101011
`define FUNC_MULT  6'b011000
`define FUNC_MULTU 6'b011001
// �������������������
`define FUNC_MADD  6'b000000
`define FUNC_MADDU 6'b000001
`define FUNC_MUL   6'b000010
`define FUNC_MSUB  6'b000100
`define FUNC_MSUBU 6'b000101
`define FUNC_CLZ   6'b100000
`define FUNC_CLO   6'b100001
// �����ڳ�������
`define FUNC_DIV   6'b011010
`define FUNC_DIVU  6'b011011
// ��֧��ת
`define FUNC_JR   6'b001000
`define FUNC_JALR 6'b001001
// �쳣���ָ��
`define FUNC_BREAK   6'b001101
`define FUNC_SYSCALL 6'b001100
`define FUNC_ERET    6'b011000
`define FUNC_TGE     6'b110000
`define FUNC_TGEU    6'b110001
`define FUNC_TLT     6'b110010
`define FUNC_TLTU    6'b110011
`define FUNC_TEQ     6'b110100
`define FUNC_TNE     6'b110110

// ALU OP
`define ALU_OP_NOP   8'h00000000
// �߼�����  
`define ALU_OP_OR    8'b00000001
`define ALU_OP_AND   8'b00000010
`define ALU_OP_XOR   8'b00000011
`define ALU_OP_NOR   8'b00000100
// λ������  
`define ALU_OP_SLL   8'b00000101
`define ALU_OP_SRL   8'b00000110
`define ALU_OP_SRA   8'b00000111
// �����ƶ�
`define ALU_OP_MFHI  8'b00001000
`define ALU_OP_MTHI  8'b00001001
`define ALU_OP_MFLO  8'b00001010
`define ALU_OP_MTLO  8'b00001011
`define ALU_OP_MFC0  8'b00001100
`define ALU_OP_MTC0  8'b00001101
`define ALU_OP_MOV   8'b00001110
// ��������������     
`define ALU_OP_ADD   8'b00001111
`define ALU_OP_ADDU  8'b00010000
`define ALU_OP_SUB   8'b00010001
`define ALU_OP_SUBU  8'b00010010
`define ALU_OP_SLT   8'b00010011
`define ALU_OP_SLTU  8'b00010100
`define ALU_OP_MULT  8'b00010101
`define ALU_OP_MULTU 8'b00010110
// �����ں���������   
`define ALU_OP_CLZ   8'b00010111
`define ALU_OP_CLO   8'b00011000
`define ALU_OP_MUL   8'b00011001
`define ALU_OP_MADD  8'b00011010
`define ALU_OP_MADDU 8'b00011011
`define ALU_OP_MSUB  8'b00011100
`define ALU_OP_MSUBU 8'b00011101
// �����ڳ�������
`define ALU_OP_DIV   8'b00011110
`define ALU_OP_DIVU  8'b00011111
// �쳣���
`define ALU_OP_TEQ   8'b00100000
`define ALU_OP_TNE   8'b00100001
`define ALU_OP_TGE   8'b00100010
`define ALU_OP_TGEU  8'b00100011
`define ALU_OP_TLT   8'b00100100
`define ALU_OP_TLTU  8'b00100101

// ALU��������
`define ALU_SEL_NOP 3'h000
`define ALU_SEL_LOGIC 3'b001
`define ALU_SEL_SHIFT 3'b010
`define ALU_SEL_MOVE 3'b011
`define ALU_SEL_ARITHMETIC 3'b100
`define ALU_SEL_JUMP_BRANCH 3'b101
`define ALU_SEL_LOAD_STORE 3'b110
`define ALU_SEL_MUL 3'b111

// MEM OP������aluselΪLOAD_STOREʱ��Ч������EXģ�鴫�ݸ�MEM
`define MEM_OP_LB  8'b11100000
`define MEM_OP_LH  8'b11100001
`define MEM_OP_LWL 8'b11100010
`define MEM_OP_LW  8'b11100011
`define MEM_OP_LBU 8'b11100100
`define MEM_OP_LHU 8'b11100101
`define MEM_OP_LWR 8'b11100110
`define MEM_OP_SB  8'b11101000
`define MEM_OP_SH  8'b11101001
`define MEM_OP_SWL 8'b11101010
`define MEM_OP_SW  8'b11101011
`define MEM_OP_SWR 8'b11101110
`define MEM_OP_LL  8'b11110000
`define MEM_OP_SC  8'b11111000

// NOPʱ�����ļĴ���
`define NOPRegAddr 5'b00000

// CP0
`define BadVAddrAddr 8'b01000000
`define CountAddr 8'b01001000
`define CompareAddr 8'b01011000
`define StatusAddr 8'b01100000
`define CauseAddr 8'b01101000
`define EPCAddr 8'b01110000
`define Config0Addr 8'b10000000
`define Config1Addr 8'b10000001
`define ErrorEPCAddr 8'b11110000

//�����ݴ���
`define BigZeroWord 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

//״̬����ͬ״̬�ĺ궨��
`define IDLE 4'b0000                    //����״̬
`define READWAIT 4'b0001              //ͻ�����ȴ���ַ����
`define READOK 4'b0010                  //ͻ�����ȴ����ݽ���
`define WRITEWAIT 4'b0011               //ͻ��д�ȴ���ַ����
`define WRITEOK 4'b0100                 //ͻ��д�������ݽ���
`define UNCACHEWAIT 4'b0101         //uncache���ȴ���ַ����
`define UNCACHEOK 4'b0110          //uncacheд��������
// �ر���ʽ��������ֹ������ƴд����ʱ�Զ������±���
// `default_nettype none
