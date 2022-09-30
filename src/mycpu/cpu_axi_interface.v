// `default_nettype none
module cpu_axi_interface
(
    input  wire        clk,
    input  wire        resetn, 

    //inst sram-like 
    input  wire        inst_req     ,
    input  wire[3:0]   inst_burst   , // 0000 -> 1 word, 1111 -> 16 words
    input  wire[31:0]  inst_addr    ,
    output reg [511:0] inst_rdata   ,
    output wire        inst_addr_ok ,
    output reg         inst_data_ok ,
    
    //data sram-like 
    input  wire        data_req     ,
    input  wire[3:0]   data_burst   , // 0000 -> 1 word, 1111 -> 16 words
    input  wire        data_wr      ,
    input  wire[63:0]  data_strb    ,
    input  wire[31:0]  data_addr    ,
    input  wire[511:0] data_wdata   ,
    output reg [511:0] data_rdata   ,
    output wire        data_addr_ok ,
    output reg         data_data_ok ,

    //axi
    //ar
    output reg[31:0]  araddr       ,
    output reg[7 :0]  arlen        ,
    output reg[2 :0]  arsize       ,
    output reg[1 :0]  arburst      ,
    output reg[3 :0]  arcache      ,
    output reg         arvalid      ,
    input  wire        arready      ,
    //r
    input  wire[31:0]  rdata        ,
    input  wire[1 :0]  rresp        ,
    input  wire        rlast        ,
    input  wire        rvalid       ,
    output reg         rready       ,
    //aw          
    output reg[31:0]  awaddr       ,
    output reg[7 :0]  awlen        ,
    output reg[2 :0]  awsize       ,
    output reg[1 :0]  awburst      ,
    output reg[3 :0]  awcache      ,
    output reg         awvalid      ,
    input  wire        awready      ,
    //w          
    output reg[31:0]  wdata        ,
    output reg[3 :0]  wstrb        ,
    output reg        wlast        ,
    output reg         wvalid       ,
    input  wire        wready       ,
    //b           
    input  wire[1 :0]  bresp        ,
    input  wire        bvalid       ,
    output reg         bready       
);
reg[2:0] size;
always @(*) begin
      case (data_strb[3:0])
		  4'b1000,
		  4'b0100,
		  4'b0010,
		  4'b0001: begin 
				size <= 3'b00;
		  end
		  4'b0011,
		  4'b1100: begin 
				size <= 3'b01;
		  end
		  default: begin 
				size <= 3'b10;
		  end
      endcase
    end
reg[31:0] read_addr;
reg[3:0] read_burst;
reg[31:0] read_result[15:0];
// [1]: 0 inst, 1 data; [0]: 0 reading, 1 done.
reg[1:0] read_if_or_mem;
reg read_en; // ʹ�ܶ�״̬����Ϊ1ʱ��״̬����ʼ����

reg[31:0] write_addr;
reg[3:0] write_burst;
reg[31:0] write_data[15:0];
reg[3:0] write_strb[15:0];
reg write_done; // 0 writing, 1 done
reg write_en; // ʹ��д״̬����Ϊ1ʱд״̬����ʼ����

// data��ַ���֣���������Ҫ��״̬��û��ʹ�ܣ���д��Ҫ��д״̬��û��ʹ��
assign data_addr_ok = data_wr ? !write_en : !read_en;
// ��ʾdata�Ѿ���������
wire data_read_req = data_req && !data_wr;
// inst��ַ���֣���״̬��û��ʹ�ܣ���dataû�з�������
assign inst_addr_ok = !read_en && !data_read_req;

// SRAM����
always @ (posedge clk) begin
    if (!resetn) begin
        read_en <= 1'b0;
        write_en <= 1'b0;
        read_addr <= 32'd0;
        write_addr <= 32'd0;
        inst_data_ok <= 1'b0;
        data_data_ok <= 1'b0;
        read_burst <= 4'b0000;
        write_burst <= 4'b0000;
    end else begin
        // �����߼�
        if (!write_en) begin
            // ��ǰû��д����
            if (data_wr) begin
                // �����һ����д
                data_data_ok <= 1'b0; // �����������
            end
            if (data_req && data_wr) begin
                // dataҪд
                // ��¼д��Ϣ
                write_addr <= data_addr;
                write_data[0] <= data_wdata[511:480];
                write_data[1] <= data_wdata[479:448];
                write_data[2] <= data_wdata[447:416];
                write_data[3] <= data_wdata[415:384];
                write_data[4] <= data_wdata[383:352];
                write_data[5] <= data_wdata[351:320];
                write_data[6] <= data_wdata[319:288];
                write_data[7] <= data_wdata[287:256];
                write_data[8] <= data_wdata[255:224];
                write_data[9] <= data_wdata[223:192];
                write_data[10] <= data_wdata[191:160];
                write_data[11] <= data_wdata[159:128];
                write_data[12] <= data_wdata[127:96];
                write_data[13] <= data_wdata[95:64];
                write_data[14] <= data_wdata[63:32];
                write_data[15] <= data_wdata[31:0];
                
                write_strb[0] <= data_strb[63:60];
                write_strb[1] <= data_strb[59:56];
                write_strb[2] <= data_strb[55:52];
                write_strb[3] <= data_strb[51:48];
                write_strb[4] <= data_strb[47:44];
                write_strb[5] <= data_strb[43:40];
                write_strb[6] <= data_strb[39:36];
                write_strb[7] <= data_strb[35:32];
                write_strb[8] <= data_strb[31:28];
                write_strb[9] <= data_strb[27:24];
                write_strb[10] <= data_strb[23:20];
                write_strb[11] <= data_strb[19:16];
                write_strb[12] <= data_strb[15:12];
                write_strb[13] <= data_strb[11:8];
                write_strb[14] <= data_strb[7:4];
                write_strb[15] <= data_strb[3:0];

                write_burst <= data_burst;

                write_en <= 1'b1; // ����д״̬��
            end else begin
                // ��д��֤д״̬���ر�
                write_en <= 1'b0;
            end
        end else begin
            // ��ǰ��д����
            if (write_done) begin
                // д����
                data_data_ok <= 1'b1; // ������������
                write_en <= 1'b0; // �ر�д״̬��
            end else begin
                // ����д
                data_data_ok <= 1'b0; // ������
                write_en <= 1'b1; // ����д״̬����
            end
        end

        if (!read_en) begin
            // ��ǰû�ж�����
            if (!data_wr) begin
                // �����һ���Ƕ�
                data_data_ok <= 1'b0; // �����������
            end
            inst_data_ok <= 1'b0; // �����������
            if (data_req && !data_wr) begin
                // dataҪ��
                // ��¼����Ϣ
                read_addr <= data_addr;
                read_burst <= data_burst;
                read_if_or_mem[1] <= 1'b1; // ��¼��ǰ��data

                read_en <= 1'b1; // ������״̬��
            end else if (inst_req) begin
                // instҪ��
                read_addr <= inst_addr;
                read_burst <= inst_burst;
                read_if_or_mem[1] <= 1'b0; // ��¼��ǰ��inst

                read_en <= 1'b1; // ������״̬��
            end else begin
                // ��д��֤��״̬���ر�
                read_en <= 1'b0;
            end
        end else begin
            // ��ǰ�ж�����
            if (read_if_or_mem[1]) begin
                // ��data
                if (read_if_or_mem[0]) begin
                    // ������
                    data_rdata[511:480] <= read_result[0];
                    data_rdata[479:448] <= read_result[1];
                    data_rdata[447:416] <= read_result[2];
                    data_rdata[415:384] <= read_result[3];
                    data_rdata[383:352] <= read_result[4];
                    data_rdata[351:320] <= read_result[5];
                    data_rdata[319:288] <= read_result[6];
                    data_rdata[287:256] <= read_result[7];
                    data_rdata[255:224] <= read_result[8];
                    data_rdata[223:192] <= read_result[9];
                    data_rdata[191:160] <= read_result[10];
                    data_rdata[159:128] <= read_result[11];
                    data_rdata[127:96] <= read_result[12];
                    data_rdata[95:64] <= read_result[13];
                    data_rdata[63:32] <= read_result[14];
                    data_rdata[31:0] <= read_result[15];
                    
                    data_data_ok <= 1'b1; // ������������
                    read_en <= 1'b0; // �رն�״̬��
                end else begin
                    // ����д
                    data_data_ok <= 1'b0; // ������
                    read_en <= 1'b1; // ���ֶ�״̬����
                end
            end else begin
                // ��inst
                if (read_if_or_mem[0]) begin
                    // ������
                    inst_rdata[511:480] <= read_result[0];
                    inst_rdata[479:448] <= read_result[1];
                    inst_rdata[447:416] <= read_result[2];
                    inst_rdata[415:384] <= read_result[3];
                    inst_rdata[383:352] <= read_result[4];
                    inst_rdata[351:320] <= read_result[5];
                    inst_rdata[319:288] <= read_result[6];
                    inst_rdata[287:256] <= read_result[7];
                    inst_rdata[255:224] <= read_result[8];
                    inst_rdata[223:192] <= read_result[9];
                    inst_rdata[191:160] <= read_result[10];
                    inst_rdata[159:128] <= read_result[11];
                    inst_rdata[127:96] <= read_result[12];
                    inst_rdata[95:64] <= read_result[13];
                    inst_rdata[63:32] <= read_result[14];
                    inst_rdata[31:0] <= read_result[15];

                    inst_data_ok <= 1'b1; // ������������
                    read_en <= 1'b0; // �رն�״̬��
                end else begin
                    // ����д
                    inst_data_ok <= 1'b0; // ������
                    read_en <= 1'b1; // ���ֶ�״̬����
                end
            end
        end
    end
end

// AXI��״̬��
reg[1:0] read_status;
// assign araddr = {3'b000, read_addr[28:0]}; // Fixed map
// assign arlen  = {4'b0000, read_burst};
// assign arsize = !read_if_or_mem[1] ? 3'b010 : read_if_or_mem[0] ? 3'b010 : size; // always transfer 4 bytes
// assign arburst = 2'b01; // incr
// assign arcache = (read_addr[31:29] == 3'b101) ? 4'b0000 : 4'b1111;
reg[3:0] read_counter;

always @ (posedge clk) begin
    if (!read_en) begin
        // û�ж�ʹ�ܣ���һֱ��λ
        read_status <= 2'b00;
        read_if_or_mem[0] <= 1'b0; // ȡ��done��λ
        read_counter <= 4'b0000;
        arvalid <= 1'b0;
        rready <= 1'b0;
        // �����źŸ�Ϊreg����
        araddr <= 32'd0;
        arlen <= 8'd0;
        arsize <= 3'b000;
        arburst <= 2'b01;
        arcache <= 4'b0000;
    end else begin
        // ����״̬
        case (read_status)
            2'b00: begin
                // AR��������
                read_status <= 2'b01;
                arvalid <= 1'b1; // ����AR����
                araddr <= {3'b000, read_addr[28:0]};
                arlen <= {4'b0000, read_burst};
                arsize <= !read_if_or_mem[1] ? 3'b010 : read_if_or_mem[0] ? 3'b010 : size;
                arburst <= 2'b01;
                arcache <= (read_addr[31:29] == 3'b101) ? 4'b0000 : 4'b1111;
            end 
            2'b01: begin
                // дARͨ������AXI��ַ����
                if (arready && arvalid) begin
                    // AR���ֳɹ�
                    read_counter <= (4'b1111 - arlen[3:0]); // ����counter  
                    // ���arlen��burst���䣬���λ��f����ȥ��counter����Ϊ0
                    // �������burst���䣬��֤���һ�δ���һ��д��31:0��
                    arvalid <= 1'b0; // ���������ź�
                    read_status <= 2'b10;
                    rready <= 1'b1; // ׼����������
                end else begin
                    arvalid <= 1'b1; // ����AR����
                    read_status <= 2'b01;
                    rready <= 1'b0;
                end
            end 
            2'b10: begin
                // �ȴ�Rͨ������������
                if (rready && rvalid) begin
                    // �������ֳɹ�
                    read_result[read_counter] <= rdata;
                    read_counter <= read_counter + 1;
                    
                    // ���һ�����������
                    if (rlast) begin
                        // �������ö���������һ������Ӧ�ùرն�״̬��ʹ��
                        // �Ӷ��ж�״̬����ִ�У������ԭ�صȴ�
                        read_if_or_mem[0] <= 1'b1; // ��ʾ������
                        rready <= 1'b0;
                    end
                end
            end 
            default: begin
                read_if_or_mem[0] <= 1'b0;
                read_status <= 2'b00;
                read_counter <= 4'b0000;
            end
        endcase
    end
end

// AXIд״̬��
reg[2:0] write_status;
// assign awaddr = {3'b000, write_addr[28:0]}; // Fixed map
// assign awlen  = {4'b0000, write_burst};
// assign awsize = 3'b010; // always transfer 4 bytes
// assign awburst = 2'b01; // incr
// assign awcache = (write_addr[31:29] == 3'b101) ? 4'b0000 : 4'b1111;
reg[3:0] write_counter;

always @ (posedge clk) begin
    if (!write_en) begin
        // û��дʹ����λ
        write_status <= 3'b000;
        write_counter <= 4'b0000;
        write_done <= 1'b0;
        awvalid <= 1'b0;
        wvalid <= 1'b0;
        bready <= 1'b0;
        awaddr <= 32'd0;
        awlen <= 8'd0;
        awsize <= 3'b010;
        awburst <= 2'b01;
        awcache <= 4'b0000;

    end else begin
        case (write_status)
            3'b000: begin
                // ����AW����
                write_status <= 3'b001;
                awvalid <= 1'b1; // ����AW����
                awaddr <= {3'b000, write_addr[28:0]};
                awlen <= {4'b0000, write_burst};
                awsize <= 3'b010;
                awburst <= 2'b01;
                awcache <= (write_addr[31:29] == 3'b101) ? 4'b0000 : 4'b1111;
            end 
            3'b001: begin
                // дAWͨ������д��ַ����
                if (awvalid && awready) begin
                    // AW���ֳɹ�
                    write_counter <= (4'b1111 - awlen[3:0]);
                    awvalid <= 1'b0;
                    write_status <= 3'b010;
                    wvalid <= 1'b1;
                end else begin
                    awvalid <= 1'b1;
                    write_status <= 3'b001;
                    wvalid <= 1'b0;
                end
            end 
            3'b010: begin
                // дWͨ���������ݴ���
                // ����ֻ����counter�Ȼ���reg
                // strb��wdata�ź����߼���·��ʱ���½�����ǰ����
                if (wvalid && wready) begin
                    // ���ֳɹ���׼����һ�δ���
                    if (write_counter != 4'b1111) begin
                        // �������һ�δ���
                        write_counter <= write_counter + 1;
                    end else begin
                        // �����һ�δ���
                        write_status <= 3'b011;
                        wvalid <= 1'b0;
                        bready <= 1'b1;
                    end
                end
            end 
            3'b011: begin
                // �ȴ�Bͨ������д����
                if (bready && bvalid) begin
                    // Bͨ�����ֳɹ������Խ��
                    // �պ����CPUʵ�������쳣
                    // �����ڴ˴��ж�д���Ƿ�ɹ�
                    bready <= 1'b0;
                    // д��������һ������Ӧ���ر�дʹ�ܽ��и�λ
                    // �����ԭ�صȴ�
                    write_done <= 1'b1; 
                end else begin
                    write_status <= 3'b011;
                end
            end 
            default: begin
                write_done <= 1'b0;
                write_status <= 3'b000;
                write_counter <= 4'b0000;
            end
        endcase
    end
end

// ����wdata��wstrb��wlast
// assign wdata = wvalid ? write_data[write_counter] : 32'd0;
// assign wstrb = wvalid ? write_strb[write_counter] : 4'd0;
wire is_last = (write_counter == 4'b1111) ? 1'b1 : 1'b0;
// assign wlast = wvalid ? is_last : 1'b0;

always @ (*) begin
    if (wvalid) begin
        wdata <= write_data[write_counter];
        wstrb <= write_strb[write_counter];
        wlast <= is_last;
    end else begin
        wdata <= 32'd0;
        wstrb <= 4'd0;
        wlast <= 1'b0;
    end
end

endmodule

