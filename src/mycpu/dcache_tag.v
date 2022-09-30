module dcache_tag(
    input wire clk,
    input wire rst,

    input wire[`RegBus] mem_addr_i,
    // 写入信号
    input wire wr,
    input wire cache_ok,

    output wire write_back,
    output wire[31:0] last_addr,
    output wire hit,
    output reg[15:0] select_offset
);

    wire[17:0] tag = mem_addr_i[31:14];
    wire[7:0] index = mem_addr_i[13:6];
    wire[3:0] offset = mem_addr_i[5:2];
    wire[17:0] tag_out;

    assign hit = valid_out & (tag_out == tag);

    assign last_addr = {tag_out,index,6'b000000};

    wire valid_in;
    assign valid_in = rst ? 1'b0 : 1'b1;
    assign write_back = dirty_out & valid_out;

    always @(*) begin
        case (offset)
            4'h0: select_offset <= 16'h0001;
            4'h1: select_offset <= 16'h0002;
            4'h2: select_offset <= 16'h0004;
            4'h3: select_offset <= 16'h0008;
            4'h4: select_offset <= 16'h0010;
            4'h5: select_offset <= 16'h0020;
            4'h6: select_offset <= 16'h0040;
            4'h7: select_offset <= 16'h0080;
            4'h8: select_offset <= 16'h0100;
            4'h9: select_offset <= 16'h0200;
            4'ha: select_offset <= 16'h0400;
            4'hb: select_offset <= 16'h0800;
            4'hc: select_offset <= 16'h1000;
            4'hd: select_offset <= 16'h2000;
            4'he: select_offset <= 16'h4000;
            4'hf: select_offset <= 16'h8000;
            default: select_offset <= 16'h0000;
        endcase
    end


    dirty_ram dirty0(
        .a(index),
        .d(hit),
        .clk(clk),
        .we(wr | cache_ok),
        .spo(dirty_out)
    );

    valid_ram valid(//给index获得vaild
        .a(index),
        .d(valid_in),
        .clk(clk),
        .we(cache_ok),
        .spo(valid_out)
    );
    //获得tag的匹配情况
    tag_ram tag0(
        .a(index),
        .d(tag),
        .clk(clk),
        .we(cache_ok),
        .spo(tag_out)
    );

endmodule