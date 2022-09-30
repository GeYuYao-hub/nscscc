module dcache_ram(
    input wire clk,
    input wire rst,
    input wire flush,

    input wire[5:0] stall,

    input wire[31:0] dcache_read_addr_i,

    input wire[31:0] dcache_write_addr_i,
    input wire[63:0] dcache_strb_i,
    input wire[511:0] dcache_data_i,

    output reg[511:0] dcache_data_o
);

wire[7:0] write_index;
assign write_index = dcache_write_addr_i[13:6];
wire[7:0] index;
assign index = dcache_read_addr_i[13:6];
// wire read_ce;
// assign read_ce = (index == write_index) ? 1'b0 : 1'b1;

// wire[511:0] data_out_a;
wire[511:0] data_out_b; 

// assign dcache_data_o = read_ce ? data_out_b : data_out_a;

always @ (posedge clk) begin
    if(rst == `RstEnable || flush) begin
        dcache_data_o <= `BigZeroWord;
    end else if (stall[3] == `Stop && stall[4] == `NoStop) begin
        dcache_data_o <= `BigZeroWord;
    end else if (stall[3] == `NoStop) begin
        // dcache_data_o <= read_ce ? data_out_b : data_out_a;
        dcache_data_o <= data_out_b;
    end else begin
    end
end


cache_ram data0(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[511:480]),
   //.douta(data_out_a[511:480]),
   //.ena(1'b1),
    .wea(dcache_strb_i[63:60]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[511:480])

);

cache_ram data1(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[479:448]),
   //.douta(data_out_a[479:448]),
   //.ena(1'b1),
    .wea(dcache_strb_i[59:56]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[479:448])
);

cache_ram data2(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[447:416]),
   //.douta(data_out_a[447:416]),
   //.ena(1'b1),
    .wea(dcache_strb_i[55:52]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[447:416])
);

cache_ram data3(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[415:384]),
   //.douta(data_out_a[415:384]),
   //.ena(1'b1),
    .wea(dcache_strb_i[51:48]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[415:384])
);

cache_ram data4(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[383:352]),
   //.douta(data_out_a[383:352]),
   //.ena(1'b1),
    .wea(dcache_strb_i[47:44]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[383:352])
);

cache_ram data5(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[351:320]),
   //.douta(data_out_a[351:320]),
   //.ena(1'b1),
    .wea(dcache_strb_i[43:40]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[351:320])
);

cache_ram data6(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[319:288]),
   //.douta(data_out_a[319:288]),
   //.ena(1'b1),
    .wea(dcache_strb_i[39:36]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[319:288])
);

cache_ram data7(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[287:256]),
   //.douta(data_out_a[287:256]),
   //.ena(1'b1),
    .wea(dcache_strb_i[35:32]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[287:256])
);

cache_ram data8(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[255:224]),
   //.douta(data_out_a[255:224]),
   //.ena(1'b1),
    .wea(dcache_strb_i[31:28]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[255:224])
);

cache_ram data9(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[223:192]),
   //.douta(data_out_a[223:192]),
   //.ena(1'b1),
    .wea(dcache_strb_i[27:24]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[223:192])
);

cache_ram data10(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[191:160]),
   //.douta(data_out_a[191:160]),
   //.ena(1'b1),
    .wea(dcache_strb_i[23:20]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[191:160])
);

cache_ram data11(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[159:128]),
   //.douta(data_out_a[159:128]),
   //.ena(1'b1),
    .wea(dcache_strb_i[19:16]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[159:128])
);

cache_ram data12(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[127:96]),
   //.douta(data_out_a[127:96]),
   //.ena(1'b1),
    .wea(dcache_strb_i[15:12]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[127:96])
);

cache_ram data13(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[95:64]),
   //.douta(data_out_a[95:64]),
   //.ena(1'b1),
    .wea(dcache_strb_i[11:8]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[95:64])
);

cache_ram data14(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[63:32]),
   //.douta(data_out_a[63:32]),
   //.ena(1'b1),
    .wea(dcache_strb_i[7:4]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[63:32])
);

cache_ram data15(
    // a端口用于写入
    .addra(write_index),
    .clka(clk),
    .dina(dcache_data_i[31:0]),
   //.douta(data_out_a[31:0]),
   //.ena(1'b1),
    .wea(dcache_strb_i[3:0]),
    // b端口用于读取
    .addrb(index),
   //.clkb(~clk),
   //.dinb(`ZeroWord),
    .doutb(data_out_b[31:0])
);


















// strb_ram data0(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[511:480]),
//     .douta(data_out_a[511:480]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[63:60]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[511:480]),
//     .enb(read_ce),
//     .web(4'h0)

// );

// strb_ram data1(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[479:448]),
//     .douta(data_out_a[479:448]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[59:56]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[479:448]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data2(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[447:416]),
//     .douta(data_out_a[447:416]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[55:52]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[447:416]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data3(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[415:384]),
//     .douta(data_out_a[415:384]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[51:48]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[415:384]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data4(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[383:352]),
//     .douta(data_out_a[383:352]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[47:44]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[383:352]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data5(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[351:320]),
//     .douta(data_out_a[351:320]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[43:40]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[351:320]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data6(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[319:288]),
//     .douta(data_out_a[319:288]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[39:36]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[319:288]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data7(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[287:256]),
//     .douta(data_out_a[287:256]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[35:32]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[287:256]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data8(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[255:224]),
//     .douta(data_out_a[255:224]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[31:28]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[255:224]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data9(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[223:192]),
//     .douta(data_out_a[223:192]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[27:24]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[223:192]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data10(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[191:160]),
//     .douta(data_out_a[191:160]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[23:20]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[191:160]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data11(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[159:128]),
//     .douta(data_out_a[159:128]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[19:16]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[159:128]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data12(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[127:96]),
//     .douta(data_out_a[127:96]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[15:12]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[127:96]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data13(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[95:64]),
//     .douta(data_out_a[95:64]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[11:8]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[95:64]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data14(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[63:32]),
//     .douta(data_out_a[63:32]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[7:4]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[63:32]),
//     .enb(read_ce),
//     .web(4'h0)
// );

// strb_ram data15(
//     // a端口用于写入
//     .addra({22'd0,write_index,2'b00}),
//     .clka(~clk),
//     .dina(dcache_data_i[31:0]),
//     .douta(data_out_a[31:0]),
//     .ena(1'b1),
//     .wea(dcache_strb_i[3:0]),
//     // b端口用于读取
//     .addrb({22'd0,index,2'b00}),
//     .clkb(~clk),
//     .dinb(`ZeroWord),
//     .doutb(data_out_b[31:0]),
//     .enb(read_ce),
//     .web(4'h0)
// );

endmodule