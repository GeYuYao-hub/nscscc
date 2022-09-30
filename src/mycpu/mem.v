
//////////////////////////////////////////////////////////////////////////////////
// �ô�׶�
// �Ĵ����� 31:24   23:16   15:8   7:0
// ��ַ��   0x03    0x02    0x01   0x00
// ���԰��ֽ�д��0x03ʱ��д��Ĵ�����8λ��selΪ1000
// ����д��ʱ������д0x00��ʵ����д��������ǼĴ�����16λ
// ��������RAM��32λ��λ��������ѡ���ַʹ�����ֽڵ�ַ��Ĵ������Ӧ��
// RAM��| 0x03 0x02 0x01 0x00 | 0x07 0x06 0x05 0x04 | ...
// ��Ϊ0x00~0x03���ʵĶ��ǵ�һ��32λ�ĵ�Ԫ�����ڲ��ֽ���ΰ�����α��ַ�Ϳ���������
// ���հ���д0x00ʱsel��Ϊ0011��������д0x10��sel����1100��
// ����������ⲿд��8�ֽ�RAM������AXI�ӿڵ�SRAM����������ת������İɣ�
// ����LWL��LWR����Ҫ���ֽ�˳���룺
// ������ַ��0x01~0x04��һ���Ƕ�����֣�Ҫ��ȡ���Ĵ�����
// | 0x00 0x01 0x02 0x03 | 0x04 0x05 0x06 0x07 |
// | a+1  a+2  a+3       |                 a   |
// ת��������˵���Զ����ַ����32λ�Ŀ���ʣ����ڵ�ַ�Զ��壩��
// | 0x03 0x02 0x01 0x00 | 0x07 0x06 0x05 0x04 |
//        a+3  a+2  a+1     a  
// ��ʱ��lwl 0x02 -> a+3 a+2 a+1 ...
//      lwr 0x07 -> ... ... ...  a 
// SWL��SWR�պ���LWL��LWR���������������д��������ˡ�
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module mem(
    input wire clk,
    input wire rst,
    
    // ����ִ�н׶ε���Ϣ    
    input wire[`RegAddrBus] waddr_i,
    input wire we_i, // д��Ч�ź�
    input wire[`RegBus] wdata_i,
    input wire we_hilo_i,
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,
    input wire[`AluOpBus] aluop_i,
    input wire[`RegBus] mem_addr_i,
    input wire[`RegBus] reg2_i,
    input wire cp0_we_i,
    input wire[7:0] cp0_waddr_i,
    input wire[`RegBus] cp0_wdata_i,
    input wire[31:0] exceptions_i,
    input wire[`RegBus] pc_i,
    input wire is_in_delayslot_i,

    // CP0�������ж��ж��ܷ�����δ�����Σ�
    input wire[`RegBus] cp0_status_i,
    input wire[`RegBus] cp0_cause_i,
    input wire[`RegBus] cp0_epc_i,

    // �쳣
    output wire[`RegBus] pc_o,
    output wire is_in_delayslot_o,
    output reg exception_occured_o, // �����쳣ʱ������ֶβ���Ч
    output reg[4:0] exc_code_o,
    output reg[`RegBus] bad_addr_o,
    
    // �͵���д�׶ε���Ϣ
    output reg[`RegAddrBus] waddr_o,
    output wire we_o,
    output reg[`RegBus] wdata_o,
    output reg we_hilo_o,
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    output reg cp0_we_o,
    output reg[7:0] cp0_waddr_o,
    output reg[`RegBus] cp0_wdata_o,
    
    // ����RAM
    input wire mem_addr_ok,
    input wire mem_data_ok,
    // ��������RAM���ź�
    output reg[`RegBus] mem_addr_o,
    output reg mem_wr_o,
    // �Ĵ����� 31:24   23:16   15:8   7:0
    // strb     1000    0100   0010   0001
    output reg[63:0] mem_strb_o,
    input wire[511:0] mem_data_i,
    output reg[511:0] mem_data_o,
    output reg mem_req_o,
    output wire[3:0] mem_data_burst,
    output reg stallreq,

    // ����д�ؽ׶ε�cache��Ϣ
    output reg[511:0] mem_data_cache_write_o,
    output reg[63:0] mem_data_strb_cache_o,
    output reg[31:0] mem_addr_cache_o,

    // ��д�ؽ׶ν�������cache��Ϣǰ�Ƶ�mem�׶�
    input wire[511:0] mem_data_cache_write_i,
    input wire[63:0] mem_data_strb_cache_i,
    input wire[31:0] mem_addr_cache_i,

    // ��dcache��������Ϣ
    input wire[511:0] dcache_data_i
    );

    // TODO: d-cache


    // д���ַ�Ļ���
    // wire[17:0] write_tag = mem_addr_cache_i[31:14];
    wire[7:0] write_index = mem_addr_cache_i[13:6];


    // �ж�uncache
    wire uncache;
    assign uncache = (mem_addr_i[31:29] & 3'b111) == 3'b101;

    reg[3:0] state;//����״̬����״̬
    wire[17:0] tag = mem_addr_i[31:14];
    wire[7:0] index = mem_addr_i[13:6];
    wire[3:0] offset = mem_addr_i[5:2];
    // wire valid_out;//�Ƿ���Ч

    wire cache_ok;//������ǵ�ǰ��״̬���Ѿ�������ϣ�������������ϣ�
    assign cache_ok = (!uncache) & (mem_data_ok && state == `READOK);

    wire hit;//�Ƿ����б�־λ

    // ѡ��wr�ź�
    reg mem_wr_temp;


    reg mem_ce;
    

    // TODO
    // �������uncache����ʹ��ͻ������
    assign mem_data_burst = uncache ? 4'b0000 : 4'b1111;

    wire[31:0] block[0:15];//��ʱ�洢ȡ�������ݣ������ṩ�ô�׶�����Ҫ�����ݣ�
    wire[511:0] block_data;//������ż�������������
    wire[31:0] last_addr;//֮ǰcache�е����ݿ�ĵ�ַ

    
    
    
     // ��cache����ȡ������
    wire[31:0] mem_data_cache_i;
    reg[31:0] mem_data_cache_o;
    // �������д����Ƿ��ʵ�ַ�������з��ʲ���
    // wire read_ce = (index == write_index) ? 1'b0 : 1'b1;

    // �����ݽ���ѡ��
wire[31:0] write_cache_vector[0:15];
wire[31:0] read_cache_vector[0:15];

    assign write_cache_vector[0] = mem_data_cache_write_i[511:480];
    assign write_cache_vector[1] = mem_data_cache_write_i[479:448];
    assign write_cache_vector[2] = mem_data_cache_write_i[447:416];
    assign write_cache_vector[3] = mem_data_cache_write_i[415:384];
    assign write_cache_vector[4] = mem_data_cache_write_i[383:352];
    assign write_cache_vector[5] = mem_data_cache_write_i[351:320];
    assign write_cache_vector[6] = mem_data_cache_write_i[319:288];
    assign write_cache_vector[7] = mem_data_cache_write_i[287:256];
    assign write_cache_vector[8] = mem_data_cache_write_i[255:224];
    assign write_cache_vector[9] = mem_data_cache_write_i[223:192];
    assign write_cache_vector[10] = mem_data_cache_write_i[191:160];
    assign write_cache_vector[11] = mem_data_cache_write_i[159:128];
    assign write_cache_vector[12] = mem_data_cache_write_i[127:96];
    assign write_cache_vector[13] = mem_data_cache_write_i[95:64];
    assign write_cache_vector[14] = mem_data_cache_write_i[63:32];
    assign write_cache_vector[15] = mem_data_cache_write_i[31:0];
    
    assign read_cache_vector[0] = dcache_data_i[511:480];
    assign read_cache_vector[1] = dcache_data_i[479:448];
    assign read_cache_vector[2] = dcache_data_i[447:416];
    assign read_cache_vector[3] = dcache_data_i[415:384];
    assign read_cache_vector[4] = dcache_data_i[383:352];
    assign read_cache_vector[5] = dcache_data_i[351:320];
    assign read_cache_vector[6] = dcache_data_i[319:288];
    assign read_cache_vector[7] = dcache_data_i[287:256];
    assign read_cache_vector[8] = dcache_data_i[255:224];
    assign read_cache_vector[9] = dcache_data_i[223:192];
    assign read_cache_vector[10] = dcache_data_i[191:160];
    assign read_cache_vector[11] = dcache_data_i[159:128];
    assign read_cache_vector[12] = dcache_data_i[127:96];
    assign read_cache_vector[13] = dcache_data_i[95:64];
    assign read_cache_vector[14] = dcache_data_i[63:32];
    assign read_cache_vector[15] = dcache_data_i[31:0];

    assign block[0] = (index == write_index) ? {{mem_data_strb_cache_i[63] ? write_cache_vector[0][31:24] : read_cache_vector[0][31:24]},
                                                {mem_data_strb_cache_i[62] ? write_cache_vector[0][23:16] : read_cache_vector[0][23:16]},
                                                {mem_data_strb_cache_i[61] ? write_cache_vector[0][15:8]  : read_cache_vector[0][15:8]},
                                                {mem_data_strb_cache_i[60] ? write_cache_vector[0][7:0]   : read_cache_vector[0][7:0]}}
                                                : read_cache_vector[0];
    assign block[1] = (index == write_index) ? {{mem_data_strb_cache_i[59] ? write_cache_vector[1][31:24] : read_cache_vector[1][31:24]},
                                                {mem_data_strb_cache_i[58] ? write_cache_vector[1][23:16] : read_cache_vector[1][23:16]},
                                                {mem_data_strb_cache_i[57] ? write_cache_vector[1][15:8]  : read_cache_vector[1][15:8]},
                                                {mem_data_strb_cache_i[56] ? write_cache_vector[1][7:0]   : read_cache_vector[1][7:0]}}
                                                : read_cache_vector[1];
    assign block[2] = (index == write_index) ? {{mem_data_strb_cache_i[55] ? write_cache_vector[2][31:24] : read_cache_vector[2][31:24]},
                                                {mem_data_strb_cache_i[54] ? write_cache_vector[2][23:16] : read_cache_vector[2][23:16]},
                                                {mem_data_strb_cache_i[53] ? write_cache_vector[2][15:8]  : read_cache_vector[2][15:8]},
                                                {mem_data_strb_cache_i[52] ? write_cache_vector[2][7:0]   : read_cache_vector[2][7:0]}}
                                                : read_cache_vector[2];
    assign block[3] = (index == write_index) ? {{mem_data_strb_cache_i[51] ? write_cache_vector[3][31:24] : read_cache_vector[3][31:24]},
                                                {mem_data_strb_cache_i[50] ? write_cache_vector[3][23:16] : read_cache_vector[3][23:16]},
                                                {mem_data_strb_cache_i[49] ? write_cache_vector[3][15:8]  : read_cache_vector[3][15:8]},
                                                {mem_data_strb_cache_i[48] ? write_cache_vector[3][7:0]   : read_cache_vector[3][7:0]}}
                                                : read_cache_vector[3];
    assign block[4] = (index == write_index) ? {{mem_data_strb_cache_i[47] ? write_cache_vector[4][31:24] : read_cache_vector[4][31:24]},
                                                {mem_data_strb_cache_i[46] ? write_cache_vector[4][23:16] : read_cache_vector[4][23:16]},
                                                {mem_data_strb_cache_i[45] ? write_cache_vector[4][15:8]  : read_cache_vector[4][15:8]},
                                                {mem_data_strb_cache_i[44] ? write_cache_vector[4][7:0]   : read_cache_vector[4][7:0]}}
                                                : read_cache_vector[4];
    assign block[5] = (index == write_index) ? {{mem_data_strb_cache_i[43] ? write_cache_vector[5][31:24] : read_cache_vector[5][31:24]},
                                                {mem_data_strb_cache_i[42] ? write_cache_vector[5][23:16] : read_cache_vector[5][23:16]},
                                                {mem_data_strb_cache_i[41] ? write_cache_vector[5][15:8]  : read_cache_vector[5][15:8]},
                                                {mem_data_strb_cache_i[40] ? write_cache_vector[5][7:0]   : read_cache_vector[5][7:0]}}
                                                : read_cache_vector[5];
    assign block[6] = (index == write_index) ? {{mem_data_strb_cache_i[39] ? write_cache_vector[6][31:24] : read_cache_vector[6][31:24]},
                                                {mem_data_strb_cache_i[38] ? write_cache_vector[6][23:16] : read_cache_vector[6][23:16]},
                                                {mem_data_strb_cache_i[37] ? write_cache_vector[6][15:8]  : read_cache_vector[6][15:8]},
                                                {mem_data_strb_cache_i[36] ? write_cache_vector[6][7:0]   : read_cache_vector[6][7:0]}}
                                                : read_cache_vector[6];
    assign block[7] = (index == write_index) ? {{mem_data_strb_cache_i[35] ? write_cache_vector[7][31:24] : read_cache_vector[7][31:24]},
                                                {mem_data_strb_cache_i[34] ? write_cache_vector[7][23:16] : read_cache_vector[7][23:16]},
                                                {mem_data_strb_cache_i[33] ? write_cache_vector[7][15:8]  : read_cache_vector[7][15:8]},
                                                {mem_data_strb_cache_i[32] ? write_cache_vector[7][7:0]   : read_cache_vector[7][7:0]}}
                                                : read_cache_vector[7];
    assign block[8] = (index == write_index) ? {{mem_data_strb_cache_i[31] ? write_cache_vector[8][31:24] : read_cache_vector[8][31:24]},
                                                {mem_data_strb_cache_i[30] ? write_cache_vector[8][23:16] : read_cache_vector[8][23:16]},
                                                {mem_data_strb_cache_i[29] ? write_cache_vector[8][15:8]  : read_cache_vector[8][15:8]},
                                                {mem_data_strb_cache_i[28] ? write_cache_vector[8][7:0]   : read_cache_vector[8][7:0]}}
                                                : read_cache_vector[8];
    assign block[9] = (index == write_index) ? {{mem_data_strb_cache_i[27] ? write_cache_vector[9][31:24] : read_cache_vector[9][31:24]},
                                                {mem_data_strb_cache_i[26] ? write_cache_vector[9][23:16] : read_cache_vector[9][23:16]},
                                                {mem_data_strb_cache_i[25] ? write_cache_vector[9][15:8]  : read_cache_vector[9][15:8]},
                                                {mem_data_strb_cache_i[24] ? write_cache_vector[9][7:0]   : read_cache_vector[9][7:0]}}
                                                : read_cache_vector[9];
    assign block[10] = (index == write_index) ?{{mem_data_strb_cache_i[23] ? write_cache_vector[10][31:24] : read_cache_vector[10][31:24]},
                                                {mem_data_strb_cache_i[22] ? write_cache_vector[10][23:16] : read_cache_vector[10][23:16]},
                                                {mem_data_strb_cache_i[21] ? write_cache_vector[10][15:8]  : read_cache_vector[10][15:8]},
                                                {mem_data_strb_cache_i[20] ? write_cache_vector[10][7:0]   : read_cache_vector[10][7:0]}}
                                                : read_cache_vector[10];
    assign block[11] = (index == write_index) ?{{mem_data_strb_cache_i[19] ? write_cache_vector[11][31:24] : read_cache_vector[11][31:24]},
                                                {mem_data_strb_cache_i[18] ? write_cache_vector[11][23:16] : read_cache_vector[11][23:16]},
                                                {mem_data_strb_cache_i[17] ? write_cache_vector[11][15:8]  : read_cache_vector[11][15:8]},
                                                {mem_data_strb_cache_i[16] ? write_cache_vector[11][7:0]   : read_cache_vector[11][7:0]}}
                                                : read_cache_vector[11];
    assign block[12] = (index == write_index) ?{{mem_data_strb_cache_i[15] ? write_cache_vector[12][31:24] : read_cache_vector[12][31:24]},
                                                {mem_data_strb_cache_i[14] ? write_cache_vector[12][23:16] : read_cache_vector[12][23:16]},
                                                {mem_data_strb_cache_i[13] ? write_cache_vector[12][15:8]  : read_cache_vector[12][15:8]},
                                                {mem_data_strb_cache_i[12] ? write_cache_vector[12][7:0]   : read_cache_vector[12][7:0]}}
                                                : read_cache_vector[12];
    assign block[13] = (index == write_index) ?{{mem_data_strb_cache_i[11] ? write_cache_vector[13][31:24] : read_cache_vector[13][31:24]},
                                                {mem_data_strb_cache_i[10] ? write_cache_vector[13][23:16] : read_cache_vector[13][23:16]},
                                                {mem_data_strb_cache_i[9]  ? write_cache_vector[13][15:8]  : read_cache_vector[13][15:8]},
                                                {mem_data_strb_cache_i[8]  ? write_cache_vector[13][7:0]   : read_cache_vector[13][7:0]}}
                                                : read_cache_vector[13];
    assign block[14] = (index == write_index) ?{{mem_data_strb_cache_i[7] ? write_cache_vector[14][31:24] : read_cache_vector[14][31:24]},
                                                {mem_data_strb_cache_i[6] ? write_cache_vector[14][23:16] : read_cache_vector[14][23:16]},
                                                {mem_data_strb_cache_i[5]  ? write_cache_vector[14][15:8]  : read_cache_vector[14][15:8]},
                                                {mem_data_strb_cache_i[4]  ? write_cache_vector[14][7:0]   : read_cache_vector[14][7:0]}}
                                                : read_cache_vector[14];
    assign block[15] = (index == write_index) ?{{mem_data_strb_cache_i[3] ? write_cache_vector[15][31:24] : read_cache_vector[15][31:24]},
                                                {mem_data_strb_cache_i[2] ? write_cache_vector[15][23:16] : read_cache_vector[15][23:16]},
                                                {mem_data_strb_cache_i[1]  ? write_cache_vector[15][15:8]  : read_cache_vector[15][15:8]},
                                                {mem_data_strb_cache_i[0]  ? write_cache_vector[15][7:0]   : read_cache_vector[15][7:0]}}
                                                : read_cache_vector[15];


    assign mem_data_cache_i = uncache ? mem_data_i[31:0] : block[offset];

    reg[3:0] mem_strb;

    wire[15:0] select_offset;

    //��dcache�е��������ݶ���˳�����һ��ͳһ�ı����У�Ȼ���ٽ������������axi��Ϊ���
    assign block_data[511:480] = block[0];
    assign block_data[479:448] = block[1];
    assign block_data[447:416] = block[2];
    assign block_data[415:384] = block[3];
    assign block_data[383:352] = block[4];
    assign block_data[351:320] = block[5];
    assign block_data[319:288] = block[6];
    assign block_data[287:256] = block[7];
    assign block_data[255:224] = block[8];
    assign block_data[223:192] = block[9];
    assign block_data[191:160] = block[10];
    assign block_data[159:128] = block[11];
    assign block_data[127:96] = block[12];
    assign block_data[95:64] = block[13];
    assign block_data[63:32] = block[14];
    assign block_data[31:0] = block[15];


    //��ͣ���ж����У������źų�ʼ����
    always @(*) begin
        if(rst == `RstEnable)begin
            stallreq <= 1'b0;
        end else begin
            case(state) 
                `IDLE: begin
                    if(mem_ce) begin
                        stallreq <= ~hit;
                    end else begin
                        stallreq <= `False_v;
                    end
                end
                `READWAIT: begin
                    stallreq <= `True_v;
                end
                `READOK: begin
                    stallreq <= `True_v;
                end
                `WRITEWAIT: begin
                    stallreq <= `True_v;
                end
                `WRITEOK: begin
                    stallreq <= `True_v;
                end
                `UNCACHEWAIT: begin
                    stallreq <= `True_v;
                end
                `UNCACHEOK: begin
                    if (!mem_data_ok) begin
                        // �������ֲ��ɹ���ԭ�صȴ�
                        stallreq <= `True_v;
                    end else begin
                        // �������ֳɹ������̳�����ˮ����ͣ
                        // ת����н׶�
                        stallreq <= `False_v;
                    end
                end
                default: begin
                    stallreq <= `False_v;
                end
            endcase
        end
    end
    
    // �����Ƿ���Ҫд��
    wire write_back;

    //״̬��
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin//��λ
            state <= `IDLE;
            mem_req_o <= 1'b0;
            mem_data_o <= `BigZeroWord;
            mem_wr_o <= 1'b0;
            mem_strb_o <= 64'h0000000000000000;
            mem_addr_o <= `ZeroWord;
        end else begin
            //ʹ�����������Խ��������ж�
            case (state)//�鿴��ǰ״̬
                `IDLE: begin//����
                    if (mem_ce & ~exception_occured_o) begin
                        if(uncache) begin
                            // uncacheֱ��д��
                            mem_wr_o <= mem_wr_temp;
                            // uncache�׶������λ����strb
                            mem_strb_o[3:0] <= mem_strb;
                            //��ǰ��ַ������ʹ��cache
                            mem_data_o[31:0] <= mem_data_cache_o[31:0];
                            state <= `UNCACHEWAIT;
                            mem_req_o <= 1'b1;
                            // ��ַ
                            mem_addr_o <= mem_addr_i;
                        end else if(!hit) begin
                            // cache�׶ν�strb�ź�ȫ����Ϊһ
                            mem_data_o <= block_data;//����ǰ�����ݴ���
                            mem_strb_o <= 64'hffffffffffffffff;
                            state <= write_back ? `WRITEWAIT : `READWAIT;
                            mem_wr_o <= write_back;
                            mem_req_o <= 1'b1;
                            mem_addr_o <= (write_back) ? last_addr : {mem_addr_i[31:6],6'b000000};
                        end else begin
                        end
                    end   
                end
                `READWAIT: begin//�ȴ���ַ�����źţ����ȴ���
                    if(mem_addr_ok == 1'b1) begin//��ַ���ճɹ�
                        mem_req_o <= 1'b0;
                        state <= `READOK;//ת�����ɹ�
                    end else begin
                    end
                end
                `READOK: begin
                    if(mem_data_ok) begin//���ݽ��ճɹ�
                        state <= `IDLE;//״̬��ת
                    end else begin
                    end
                end
                `WRITEWAIT: begin//д�ȴ�
                    if(mem_addr_ok) begin
                        state <= `WRITEOK;//ת��д�ɹ�
                        mem_req_o <= 1'b1;
                    end else begin
                    end
                end
                `WRITEOK: begin//д�ɹ�
                    if(mem_data_ok)begin
                        state <= `READWAIT;//״̬ת�����ȴ�
                        mem_req_o <= 1'b1;
                        mem_wr_o <= 1'b0;
                        mem_addr_o <= {mem_addr_i[31:6],6'b000000};
                    end else begin
                    end
                end
                `UNCACHEWAIT: begin//��cache���ٲ���
                    if(mem_addr_ok) begin
                        state <= `UNCACHEOK;//��cacheֱ�Ӷ��ɹ�
                        mem_req_o <= 1'b0;
                    end else begin
                    end
                end
                `UNCACHEOK: begin//��cacheֱ�Ӷ��ɹ�
                    if(mem_data_ok) begin//���ݽ��ճɹ�
                        state <= `IDLE;
                    end else begin
                    end
                end
                default: begin

                end
            endcase
        end
    end

dcache_tag dcache_tag0(
    .clk(clk),
    .rst(rst),
    .mem_addr_i(mem_addr_i),
    .cache_ok(cache_ok & ~exception_occured_o),
    .wr(mem_wr_temp & ~exception_occured_o),
    .write_back(write_back),
    .last_addr(last_addr),
    .hit(hit),
    .select_offset(select_offset)
);


always @ (*) begin
    mem_data_strb_cache_o[63:60] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[0] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[59:56] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[1] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[55:52] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[2] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[51:48] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[3] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[47:44] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[4] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[43:40] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[5] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[39:36] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[6] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[35:32] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[7] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[31:28] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[8] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[27:24] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[9] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[23:20] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[10] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[19:16] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[11] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[15:12] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[12] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[11:8] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[13] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[7:4] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[14] & mem_wr_temp)) ? mem_strb : 4'h0;
    mem_data_strb_cache_o[3:0] <= (cache_ok) ? 4'hf : ((~exception_occured_o & hit) & (select_offset[15] & mem_wr_temp)) ? mem_strb : 4'h0;
end


always @ (*) begin
    mem_data_cache_write_o[511:480] <= (cache_ok) ? mem_data_i[511:480] : mem_data_cache_o;
    mem_data_cache_write_o[479:448] <= (cache_ok) ? mem_data_i[479:448] : mem_data_cache_o;
    mem_data_cache_write_o[447:416] <= (cache_ok) ? mem_data_i[447:416] : mem_data_cache_o;
    mem_data_cache_write_o[415:384] <= (cache_ok) ? mem_data_i[415:384] : mem_data_cache_o;
    mem_data_cache_write_o[383:352] <= (cache_ok) ? mem_data_i[383:352] : mem_data_cache_o;
    mem_data_cache_write_o[351:320] <= (cache_ok) ? mem_data_i[351:320] : mem_data_cache_o;
    mem_data_cache_write_o[319:288] <= (cache_ok) ? mem_data_i[319:288] : mem_data_cache_o;
    mem_data_cache_write_o[287:256] <= (cache_ok) ? mem_data_i[287:256] : mem_data_cache_o;
    mem_data_cache_write_o[255:224] <= (cache_ok) ? mem_data_i[255:224] : mem_data_cache_o;
    mem_data_cache_write_o[223:192] <= (cache_ok) ? mem_data_i[223:192] : mem_data_cache_o;
    mem_data_cache_write_o[191:160] <= (cache_ok) ? mem_data_i[191:160] : mem_data_cache_o;
    mem_data_cache_write_o[159:128] <= (cache_ok) ? mem_data_i[159:128] : mem_data_cache_o;
    mem_data_cache_write_o[127:96] <= (cache_ok) ? mem_data_i[127:96] :   mem_data_cache_o;
    mem_data_cache_write_o[95:64] <= (cache_ok) ? mem_data_i[95:64] :     mem_data_cache_o;
    mem_data_cache_write_o[63:32] <= (cache_ok) ? mem_data_i[63:32] :     mem_data_cache_o;
    mem_data_cache_write_o[31:0] <= (cache_ok) ? mem_data_i[31:0] :       mem_data_cache_o;
end 

    assign we_o = exception_occured_o ? `WriteDisable : we_i;

    assign is_in_delayslot_o = is_in_delayslot_i;
    assign pc_o = pc_i;
    reg read_exception;
    reg write_exception;

    // �����쳣ExcCode
    always @ (*) begin
        if (rst == `RstEnable) begin
            exception_occured_o <= `False_v;
            exc_code_o <= 5'b00000;
            bad_addr_o <= `ZeroWord;
        end else begin
            // �ȴ�cpu��λ�������ˮ��
            if (pc_i != `ZeroWord) begin
                exception_occured_o <= `True_v; // Ĭ�����쳣
                if (((cp0_cause_i[15:8] & cp0_status_i[15:8]) != 8'd0) // ��δ�����ε��ж�����
                && cp0_status_i[2] == 1'b0 && cp0_status_i[1] == 1'b0 // �����쳣���������
                && cp0_status_i[0] == 1'b1 /* ���жϿ��� */)  begin
                    exc_code_o <= 5'h00;
                end else if (exceptions_i[0]) begin
                    // PCȡָδ����
                    exc_code_o <= 5'h04;
                    bad_addr_o <= pc_i;
                end else if (exceptions_i[1]) begin
                    // ��Чָ��
                    exc_code_o <= 5'h0a;
                end else if (exceptions_i[5]) begin
                    // ���
                    exc_code_o <= 5'h0c;
                end else if (exceptions_i[6]) begin
                    // ����
                    exc_code_o <= 5'h0d;
                end else if (exceptions_i[4]) begin
                    // Syscall����
                    exc_code_o <= 5'h08;
                end else if (exceptions_i[3]) begin
                    // Break����
                    exc_code_o <= 5'h09;
                end else if (read_exception) begin
                    exc_code_o <= 5'h04;
                    bad_addr_o <= mem_addr_i;
                end else if (write_exception) begin
                    exc_code_o <= 5'h05;
                    bad_addr_o <= mem_addr_i;
                end else if (exceptions_i[2]) begin
                    // ERET����
                    exc_code_o <= 5'h10; // MIPS32��δ����ERET������ʹ��implementation dependent use
                end else begin
                    exception_occured_o <= `False_v;
                end
            end else begin
                exception_occured_o <= `False_v;
            end
        end
    end

    wire[`RegBus] zero32 = `ZeroWord;

    always @ (*) begin
        read_exception <= `False_v;
        write_exception <= `False_v;
        mem_wr_temp <= `WriteDisable;
        mem_ce <= `ChipDisable;
        if(rst == `RstEnable) begin
            waddr_o <= `NOPRegAddr;
            wdata_o <= `ZeroWord;
            we_hilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
            mem_strb[3:0] <= 4'b0000;
            cp0_we_o <= `WriteDisable;
            cp0_waddr_o <= 8'b00000000;
            cp0_wdata_o <= `ZeroWord;
            mem_data_cache_o <= `ZeroWord;//�¼�
            mem_addr_cache_o <= `ZeroWord;
        end else begin
            waddr_o <= waddr_i;
            wdata_o <= wdata_i;
            we_hilo_o <= we_hilo_i;
            hi_o <= hi_i;
            lo_o <= lo_i;
            mem_strb[3:0] <= 4'b1111;
            cp0_we_o <= cp0_we_i;
            cp0_waddr_o <= cp0_waddr_i;
            cp0_wdata_o <= cp0_wdata_i;
            mem_addr_cache_o <= mem_addr_i;
            // �������MEM_OP����wdata��mem_data��mem_sel��Ƭѡ��дʹ��
            case (aluop_i)
                // LB
                `MEM_OP_LB: begin
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            wdata_o <= {{24{mem_data_cache_i[7]}},mem_data_cache_i[7:0]};
                            mem_strb[3:0] <= 4'b0001;
                        end
                        2'b01: begin
                            wdata_o <= {{24{mem_data_cache_i[15]}},mem_data_cache_i[15:8]};
                            mem_strb[3:0] <= 4'b0010;
                        end
                        2'b10: begin
                            wdata_o <= {{24{mem_data_cache_i[23]}},mem_data_cache_i[23:16]};
                            mem_strb[3:0] <= 4'b0100;
                        end
                        2'b11: begin
                            wdata_o <= {{24{mem_data_cache_i[31]}},mem_data_cache_i[31:24]};
                            mem_strb[3:0] <= 4'b1000;
                        end
                        default: begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase
                end
                // LH
                `MEM_OP_LH: begin
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            wdata_o <= {{16{mem_data_cache_i[15]}}, mem_data_cache_i[15:0]};
                            mem_strb[3:0] <= 4'b0011;
                        end
                        2'b10: begin
                            wdata_o <= {{16{mem_data_cache_i[31]}}, mem_data_cache_i[31:16]};
                            mem_strb[3:0] <= 4'b1100;
                        end
                        default: begin
                            // ��ʱһ�������û�ж��룬Ӧ���׵�ַ�쳣
                            read_exception <= `True_v;
                            wdata_o <= `ZeroWord;
                            mem_ce <= `ChipDisable;
                        end
                    endcase
                end
                // LWL
                `MEM_OP_LWL: begin
                    mem_strb[3:0] <= 4'b1111;
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            wdata_o <= {mem_data_cache_i[7:0],reg2_i[23:0]};
                        end
                        2'b01: begin
                            wdata_o <= {mem_data_cache_i[15:0],reg2_i[15:0]};
                        end
                        2'b10: begin
                            wdata_o <= {mem_data_cache_i[23:0],reg2_i[7:0]};
                        end
                        2'b11: begin
                            wdata_o <= mem_data_cache_i[31:0];
                        end
                        default: begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase
                end
                // LW
                `MEM_OP_LW: begin
                    wdata_o <= mem_data_cache_i[31:0];
                    mem_strb[3:0] <= 4'b1111;
                    mem_ce <= `ChipEnable;
                    if (mem_addr_i[1:0] != 2'b00) begin 
                        read_exception <= `True_v;
                        mem_ce <= `ChipDisable;
                    end
                end
                // LBU
                `MEM_OP_LBU: begin
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            wdata_o <= {{24{1'b0}},mem_data_cache_i[7:0]};
                            mem_strb[3:0] <= 4'b0001;
                        end
                        2'b01: begin
                            wdata_o <= {{24{1'b0}},mem_data_cache_i[15:8]};
                            mem_strb[3:0] <= 4'b0010;
                        end
                        2'b10: begin
                            wdata_o <= {{24{1'b0}},mem_data_cache_i[23:16]};
                            mem_strb[3:0] <= 4'b0100;
                        end
                        2'b11: begin
                            wdata_o <= {{24{1'b0}},mem_data_cache_i[31:24]};
                            mem_strb[3:0] <= 4'b1000;
                        end
                        default: begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase
                end
                // LHU
                `MEM_OP_LHU: begin
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            wdata_o <= {{16{1'b0}}, mem_data_cache_i[15:0]};
                            mem_strb[3:0] <= 4'b0011;
                        end
                        2'b10: begin
                            wdata_o <= {{16{1'b0}}, mem_data_cache_i[31:16]};
                            mem_strb[3:0] <= 4'b1100;
                        end
                        default: begin
                            read_exception <= `True_v;
                            wdata_o <= `ZeroWord;
                            mem_ce <= `ChipDisable;
                        end
                    endcase
                end
                // LWR
                `MEM_OP_LWR: begin
                    mem_strb[3:0] <= 4'b1111;
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            wdata_o <= mem_data_cache_i[31:0];
                        end
                        2'b01: begin
                            wdata_o <= {reg2_i[31:24],mem_data_cache_i[31:8]};
                        end
                        2'b10: begin
                            wdata_o <= {reg2_i[31:16],mem_data_cache_i[31:16]};
                        end
                        2'b11: begin
                            wdata_o <= {reg2_i[31:8],mem_data_cache_i[31:24]};
                        end
                        default: begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase
                end
                // SB
                `MEM_OP_SB: begin
                    mem_wr_temp <= `WriteEnable;
                    // ��Ϊֻд��1byte�����ȫ���������λҪд�������
                    mem_data_cache_o[31:0] <= {reg2_i[7:0],reg2_i[7:0],reg2_i[7:0],reg2_i[7:0]};
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            mem_strb[3:0] <= 4'b0001;
                        end
                        2'b01: begin
                            mem_strb[3:0] <= 4'b0010;
                        end
                        2'b10: begin
                            mem_strb[3:0] <= 4'b0100;
                        end
                        2'b11: begin
                            mem_strb[3:0] <= 4'b1000;
                        end
                        default: begin
                            mem_strb[3:0] <= 4'b0000;
                        end
                    endcase
                end
                // SH
                `MEM_OP_SH: begin
                    mem_wr_temp <= `WriteEnable;
                    mem_data_cache_o[31:0] <= {reg2_i[15:0], reg2_i[15:0]};
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            mem_strb[3:0] <= 4'b0011;
                        end
                        2'b10: begin
                            mem_strb[3:0] <= 4'b1100;
                        end
                        default: begin
                            write_exception <= `True_v;
                            mem_strb[3:0] <= 4'b0000;
                            mem_ce <= `ChipDisable;
                        end
                    endcase
                end
                // SWL
                `MEM_OP_SWL: begin
                    mem_wr_temp <= `WriteEnable;
                    mem_data_cache_o[31:0] <= reg2_i;
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            mem_strb[3:0] <= 4'b0001;
                            mem_data_cache_o[31:0] <= {zero32[23:0],reg2_i[31:24]};
                        end
                        2'b01: begin
                            mem_strb[3:0] <= 4'b0011;
                            mem_data_cache_o[31:0] <= {zero32[15:0],reg2_i[31:16]};
                        end
                        2'b10: begin
                            mem_strb[3:0] <= 4'b0111;
                            mem_data_cache_o[31:0] <= {zero32[7:0],reg2_i[31:8]};
                        end
                        2'b11: begin
                            mem_strb[3:0] <= 4'b1111;
                            mem_data_cache_o[31:0] <= reg2_i;
                        end
                        default: begin
                            mem_strb[3:0] <= 4'b0000;
                        end
                    endcase
                end
                // SW
                `MEM_OP_SW: begin
                    mem_wr_temp <= `WriteEnable;
                    mem_data_cache_o[31:0] <= reg2_i;
                    mem_strb[3:0] <= 4'b1111;
                    mem_ce <= `ChipEnable;
                    if (mem_addr_i[1:0] != 2'b00) begin
                        write_exception <= `True_v;
                        mem_ce <= `ChipDisable;
                    end
                end
                // SWR
                `MEM_OP_SWR: begin
                    mem_wr_temp <= `WriteEnable;
                    mem_data_cache_o[31:0] <= reg2_i;
                    mem_ce <= `ChipEnable;
                    case (mem_addr_i[1:0])
                        2'b00: begin
                            mem_strb[3:0] <= 4'b1111;
                            mem_data_cache_o[31:0] <= reg2_i[31:0];
                        end
                        2'b01: begin
                            mem_strb[3:0] <= 4'b1110;
                            mem_data_cache_o[31:0] <= {reg2_i[23:0],zero32[7:0]};
                        end
                        2'b10: begin
                            mem_strb[3:0] <= 4'b1100;
                            mem_data_cache_o[31:0] <= {reg2_i[15:0],zero32[15:0]};
                        end
                        2'b11: begin
                            mem_strb[3:0] <= 4'b1000;
                            mem_data_cache_o[31:0] <= {reg2_i[7:0],zero32[23:0]};
                        end
                        default: begin
                            mem_strb[3:0] <= 4'b0000;
                        end
                    endcase
                end
                // LL
                `MEM_OP_LL: begin
                    // TODO LL
                end
                // SC
                `MEM_OP_SC: begin
                    // TODO SC
                end
                default: begin
                end
            endcase
        end
    end
    
endmodule
