`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// HikariMIPS顶层文件
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module mycpu_top(
    input wire[5:0] ext_int,   //high active

    input wire aclk,
    input wire aresetn,   //low active

    output wire[3 :0]  arid,
    output wire[31:0]  araddr,
    output wire[7 :0]  arlen,
    output wire[2 :0]  arsize,
    output wire[1 :0]  arburst,
    output wire[1 :0]  arlock,
    output wire[3 :0]  arcache,
    output wire[2 :0]  arprot,
    output wire        arvalid,
    input  wire        arready,
    //r           
    input  wire[3 :0]  rid,
    input  wire[31:0]  rdata,
    input  wire[1 :0]  rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    //aw          
    output wire[3 :0]  awid,
    output wire[31:0]  awaddr,
    output wire[7 :0]  awlen,
    output wire[2 :0]  awsize,
    output wire[1 :0]  awburst,
    output wire[1 :0]  awlock,
    output wire[3 :0]  awcache,
    output wire[2 :0]  awprot,
    output wire        awvalid,
    input  wire        awready,
    //w          
    output wire[3 :0]  wid,
    output wire[31:0]  wdata,
    output wire[3 :0]  wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    //b           
    input  wire[3 :0]  bid,
    input  wire[1 :0]  bresp,
    input  wire        bvalid,
    output wire        bready,

    //debug interface
    (*mark_debug = "true"*)output wire[31:0] debug_wb_pc,
    (*mark_debug = "true"*)output wire[3:0] debug_wb_rf_wen,
    (*mark_debug = "true"*)output wire[4:0] debug_wb_rf_wnum,
    (*mark_debug = "true"*)output wire[31:0] debug_wb_rf_wdata
    );

    wire[`RegBus] inst_addr;
    wire[511:0] inst_rdata;
    wire[3:0] inst_burst;
    wire inst_req;
    wire inst_addr_ok;
    wire inst_data_ok;

    wire[`RegBus] data_addr;
    wire[511:0] data_wdata;
    wire[511:0] data_rdata;
    wire[63:0] data_strb;
    wire[3:0] data_burst;
    wire data_req;
    wire data_wr;
    wire data_addr_ok;
    wire data_data_ok;

    
    wire initializing;


    // cpu 模块
    hhhh_mips hhhh0(
    .clk(aclk),
    // .rst(~aresetn | initializing),
    .rst(~aresetn),

    // TODO

    // 指令ROM类SRAM接口
    .inst_req(inst_req),
    .inst_burst(inst_burst),
    .inst_addr(inst_addr),
    .inst_rdata(inst_rdata),
    .inst_addr_ok(inst_addr_ok),
    .inst_data_ok(inst_data_ok),

    // 数据RAM类SRAM接口
    .data_req(data_req),
    .data_burst(data_burst),
    .data_wr(data_wr),
    .data_strb(data_strb),
    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_addr_ok(data_addr_ok),
    .data_data_ok(data_data_ok),
    
    .init_i(ext_int[4:0]),
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_wen(debug_wb_rf_wen),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    assign wid = 4'b0000; // AIX4 has no wid
    assign arid = 4'b0000;
    assign arlock = 2'b00;
    assign arprot = 3'b000;
    assign awid = 4'b0000;
    assign awlock = 2'b00;
    assign awprot = 3'b000;

    
    wire[31:0]  cache_araddr;
    wire[7 :0]  cache_arlen;
    wire[2 :0]  cache_arsize;
    wire[1 :0]  cache_arburst;
    wire[3 :0]  cache_arcache;
    wire        cache_arvalid;
    wire        cache_arready;
    //r           
    wire[31:0]  cache_rdata;
    wire[1 :0]  cache_rresp;
    wire        cache_rlast;
    wire        cache_rvalid;
    wire        cache_rready;
    //aw          
    wire[31:0]  cache_awaddr;
    wire[7 :0]  cache_awlen;
    wire[2 :0]  cache_awsize;
    wire[1 :0]  cache_awburst;
    wire[3 :0]  cache_awcache;
    wire        cache_awvalid;
    wire        cache_awready;
    //w          
    wire[31:0]  cache_wdata;
    wire[3 :0]  cache_wstrb;
    wire        cache_wlast;
    wire        cache_wvalid;
    wire        cache_wready;
    //b           
    wire[1 :0]  cache_bresp;
    wire        cache_bvalid;
    wire        cache_bready;


    // 没有systemcache的axi总线
    cpu_axi_interface cpu_axi_interface0(
    .clk(aclk),
    .resetn(aresetn), 

    .inst_req(inst_req),
    .inst_burst(inst_burst),
    .inst_addr(inst_addr),
    .inst_rdata(inst_rdata),
    .inst_addr_ok(inst_addr_ok),
    .inst_data_ok(inst_data_ok),

    .data_req(data_req),
    .data_burst(data_burst),
    .data_wr(data_wr),
    .data_strb(data_strb),
    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_addr_ok(data_addr_ok),
    .data_data_ok(data_data_ok),

    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arcache(arcache),
    .arvalid(arvalid),
    .arready(arready),
    
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awcache(awcache),
    .awvalid(awvalid),
    .awready(awready),
    
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
    );

    /*
     * 有systemcache的总线，如果要使用请注释掉上面的总线
     */
    // cpu_axi_interface cpu_axi_interface0(
    // .clk(aclk),
    // .resetn(aresetn), 

    // .inst_req(inst_req),
    // .inst_burst(inst_burst),
    // .inst_addr(inst_addr),
    // .inst_rdata(inst_rdata),
    // .inst_addr_ok(inst_addr_ok),
    // .inst_data_ok(inst_data_ok),

    // .data_req(data_req),
    // .data_burst(data_burst),
    // .data_wr(data_wr),
    // .data_strb(data_strb),
    // .data_addr(data_addr),
    // .data_wdata(data_wdata),
    // .data_rdata(data_rdata),
    // .data_addr_ok(data_addr_ok),
    // .data_data_ok(data_data_ok),

    // .araddr(cache_araddr),
    // .arlen(cache_arlen),
    // .arsize(cache_arsize),
    // .arburst(cache_arburst),
    // .arcache(cache_arcache),
    // .arvalid(cache_arvalid),
    // .arready(cache_arready),
    
    // .rdata(cache_rdata),
    // .rresp(cache_rresp),
    // .rlast(cache_rlast),
    // .rvalid(cache_rvalid),
    // .rready(cache_rready),
    
    // .awaddr(cache_awaddr),
    // .awlen(cache_awlen),
    // .awsize(cache_awsize),
    // .awburst(cache_awburst),
    // .awcache(cache_awcache),
    // .awvalid(cache_awvalid),
    // .awready(cache_awready),
    
    // .wdata(cache_wdata),
    // .wstrb(cache_wstrb),
    // .wlast(cache_wlast),
    // .wvalid(cache_wvalid),
    // .wready(cache_wready),
    
    // .bresp(cache_bresp),
    // .bvalid(cache_bvalid),
    // .bready(cache_bready)
    // );

    // system_cache_0 cache0(
    //     .ACLK(aclk),
    //     .ARESETN(aresetn),
    //     .Initializing(initializing),

    //     .S0_AXI_ARADDR(cache_araddr),
    //     .S0_AXI_ARBURST(cache_arburst),
    //     .S0_AXI_ARCACHE(cache_arcache),
    //     .S0_AXI_ARID(1'b0),
    //     .S0_AXI_ARLEN(cache_arlen),
    //     .S0_AXI_ARLOCK(1'b0),
    //     .S0_AXI_ARPROT(3'b000),
    //     .S0_AXI_ARQOS(4'b0000),
    //     .S0_AXI_ARREADY(cache_arready),
    //     .S0_AXI_ARSIZE(cache_arsize),
    //     .S0_AXI_ARUSER(1'b0),
    //     .S0_AXI_ARVALID(cache_arvalid),

    //     .S0_AXI_AWADDR(cache_awaddr),
    //     .S0_AXI_AWBURST(cache_awburst),
    //     .S0_AXI_AWCACHE(cache_awcache),
    //     .S0_AXI_AWID(1'b0),
    //     .S0_AXI_AWLEN(cache_awlen),
    //     .S0_AXI_AWLOCK(1'b0),
    //     .S0_AXI_AWPROT(3'b000),
    //     .S0_AXI_AWQOS(4'b0000),
    //     .S0_AXI_AWREADY(cache_awready),
    //     .S0_AXI_AWSIZE(cache_awsize),
    //     .S0_AXI_AWUSER(1'b0),
    //     .S0_AXI_AWVALID(cache_awvalid),

    //     .S0_AXI_BID(4'b0000),
    //     .S0_AXI_BREADY(cache_bready),
    //     .S0_AXI_BRESP(cache_bresp),
    //     .S0_AXI_BVALID(cache_bvalid),

    //     .S0_AXI_RDATA(cache_rdata),
    //     .S0_AXI_RID(4'b0000),
    //     .S0_AXI_RLAST(cache_rlast),
    //     .S0_AXI_RREADY(cache_rready),
    //     .S0_AXI_RRESP(cache_rresp),
    //     .S0_AXI_RVALID(cache_rvalid),

    //     .S0_AXI_WDATA(cache_wdata),
    //     .S0_AXI_WLAST(cache_wlast),
    //     .S0_AXI_WREADY(cache_wready),
    //     .S0_AXI_WSTRB(cache_wstrb),
    //     .S0_AXI_WVALID(cache_wvalid),

    //     .M0_AXI_ARID(),
    //     .M0_AXI_ARADDR(araddr),
    //     .M0_AXI_ARBURST(arburst),
    //     .M0_AXI_ARCACHE(arcache),
    //     .M0_AXI_ARLEN(arlen),
    //     .M0_AXI_ARLOCK(),
    //     .M0_AXI_ARPROT(),
    //     .M0_AXI_ARREADY(arready),
    //     .M0_AXI_ARSIZE(arsize),
    //     .M0_AXI_ARVALID(arvalid),
    //     .M0_AXI_ARQOS(),
        
    //     .M0_AXI_AWID(),
    //     .M0_AXI_AWADDR(awaddr),
    //     .M0_AXI_AWBURST(awburst),
    //     .M0_AXI_AWCACHE(awcache),
    //     .M0_AXI_AWLEN(awlen),
    //     .M0_AXI_AWLOCK(),
    //     .M0_AXI_AWPROT(),
    //     .M0_AXI_AWREADY(awready),
    //     .M0_AXI_AWSIZE(awsize),
    //     .M0_AXI_AWVALID(awvalid),
    //     .M0_AXI_AWQOS(),

    //     .M0_AXI_BID(bid),
    //     .M0_AXI_BREADY(bready),
    //     .M0_AXI_BVALID(bvalid),
    //     .M0_AXI_BRESP(bresp),

    //     .M0_AXI_RID(rid),
    //     .M0_AXI_RDATA(rdata),
    //     .M0_AXI_RLAST(rlast),
    //     .M0_AXI_RREADY(rready),
    //     .M0_AXI_RRESP(rresp),
    //     .M0_AXI_RVALID(rvalid),

    //     .M0_AXI_WDATA(wdata),
    //     .M0_AXI_WLAST(wlast),
    //     .M0_AXI_WREADY(wready),
    //     .M0_AXI_WSTRB(wstrb),
    //     .M0_AXI_WVALID(wvalid)
    // );

endmodule
