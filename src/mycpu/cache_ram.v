module cache_ram(
    input wire[7:0] addra,
    input wire clka,
    input wire[31:0] dina,
    input wire[3:0] wea,

    // b
    input wire[7:0] addrb,
    output reg[31:0] doutb
);

// 存放数据
// reg[7:0] data3[0:255];
// reg[7:0] data2[0:255];
// reg[7:0] data1[0:255];
// reg[7:0] data0[0:255];
wire[31:0] dpo;

dcache_dram data3(
    .a(addra),
    .d(dina[31:24]),
    .dpra(addrb),
    .clk(clka),
    .we(wea[3]),
    .dpo(dpo[31:24])
);

dcache_dram data2(
    .a(addra),
    .d(dina[23:16]),
    .dpra(addrb),
    .clk(clka),
    .we(wea[2]),
    .dpo(dpo[23:16])
);

dcache_dram data1(
    .a(addra),
    .d(dina[15:8]),
    .dpra(addrb),
    .clk(clka),
    .we(wea[1]),
    .dpo(dpo[15:8])
);

dcache_dram data0(
    .a(addra),
    .d(dina[7:0]),
    .dpra(addrb),
    .clk(clka),
    .we(wea[0]),
    .dpo(dpo[7:0])
);

wire addr_eq = (addra == addrb);

// integer i;
// initial begin
//     for(i=0; i <256; i = i+1) begin
//         data3[i] = 8'd0;
//         data2[i] = 8'd0;
//         data1[i] = 8'd0;
//         data0[i] = 8'd0;
//     end
// end

// // 写入操作
// always@(posedge clka) begin
//     data3[addra] <= wea[3] ? dina[31:24] : data3[addra];
//     data2[addra] <= wea[2] ? dina[23:16] : data2[addra];
//     data1[addra]  <= wea[1] ? dina[15:8] : data1[addra];
//     data0[addra]  <= wea[0] ? dina[7:0] : data0[addra];
// end


// 读出操作
always @ (*) begin
    doutb[31:24] <= (addr_eq & wea[3]) ? dina[31:24] : dpo[31:24];
    doutb[23:16] <= (addr_eq & wea[2]) ? dina[23:16] : dpo[23:16];
    doutb[15:8] <= (addr_eq & wea[1]) ? dina[15:8] : dpo[15:8];
    doutb[7:0] <= (addr_eq & wea[0]) ? dina[7:0] : dpo[7:0];
end

endmodule