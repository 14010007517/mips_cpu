module cpu_axi_interface
(
    input         clk,
    input         resetn, 

	input  [ 3:0] data_sram_wen,
    //inst sram-like 
    input         inst_req     , // inst_ram 的使能信号
    input         inst_wr      , // 恒为0 ，仅读取
    input  [1 :0] inst_size    ,
    input  [31:0] inst_addr    ,
    input  [31:0] inst_wdata   ,
    output [31:0] inst_rdata   ,
    output        inst_addr_ok ,
    output        inst_data_ok ,
    
    //data sram-like 
    input         data_req     ,    // data_ram en
    input         data_wr      ,    // data_sram的写信号
    input  [1 :0] data_size    ,        
    input  [31:0] data_addr    ,
    input  [31:0] data_wdata   ,
    output [31:0] data_rdata   ,
    output        data_addr_ok ,
    output        data_data_ok ,

    //axi
    //ar    读地址
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [7 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock       ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
    //r     读数据 
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready       ,
    //aw  写地址   
    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [7 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,
    //w  写数据        
    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,
    //b           
    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready       
);
reg         req_reg;
reg         wr_reg;
reg         addr_sd;
reg         wdata_sd;
reg  [ 1:0] size_reg;
reg  [ 3:0] wen_reg;
reg  [31:0] addr_reg, wdata_reg;
wire        rcomplete, wcomplete;
always @ (posedge clk)
begin
	if(resetn)
	begin
    // 
		req_reg  <= (data_req || inst_req) & ~req_reg ? 1'b1 :
			        (rcomplete || wcomplete) ? 1'b0 : req_reg;
        // 当接受到data_req 与 inst_req 的信号时， 且没有被处理，req置上；若没有inst_req 或者data_req信号，或者已经被处理，此时若传输完成，则置0，若传输没有完成，则保持原有状态，
        // rcomlete 表示地址请求； wcomlete 表示 数据请求
        // 为什么用两个信号来表示，读写通道是分开的啊，一共五个通道

        
		wr_reg   <= data_req&&data_addr_ok ? data_wr :
		        	inst_req&&inst_addr_ok ? inst_wr : 
					wr_reg;
        // 写信号: 当




		size_reg <= data_req&&data_addr_ok ? data_size :
					inst_req&&inst_addr_ok ? inst_size : size_reg;
		addr_reg <= data_req&&data_addr_ok ? data_addr :
					inst_req&&inst_addr_ok ? inst_addr : addr_reg;
		wdata_reg <= data_req&&data_addr_ok ? data_wdata :
					 inst_req&&inst_addr_ok ? inst_wdata : wdata_reg;
        
        // awvalid 依赖于addr_sd, 而addr_sd 与awready有关， 这是不是造成了死锁；
		addr_sd  <= ((awvalid && awready) || (arvalid && arready)) ? 1'b1 :
			        (rcomplete || wcomplete) ? 1'b0 : 
					addr_sd;
		wdata_sd <= (wvalid && wready) ? 1'b1 :
			        (rcomplete || wcomplete) ? 1'b0 :
					wdata_sd;
		wen_reg <= data_req && data_addr_ok ? data_sram_wen : wen_reg;
	end else begin
		req_reg  <= 1'b0;
		size_reg <= 2'd0;
		addr_reg <= 32'd0;
		wdata_reg <= 32'd0;
		addr_sd  <= 1'd0;
		wdata_sd  <= 1'd0;
		wen_reg <= 4'd0;
	end
end

//inst sram-like
assign inst_rdata = rdata;
// inst_ram 发送地址成功
assign inst_addr_ok = ~req_reg && ~data_req;
// inst_ram 的 输出数据握手成功
assign inst_data_ok = req_reg && rcomplete;
//data sram-like
assign data_rdata = rdata;
assign data_addr_ok = ~req_reg;
assign data_data_ok = req_reg && (rcomplete || (wcomplete && bvalid));

//  ？？？？ 完成信号？？
assign rcomplete = addr_sd && (rvalid && rready);
assign wcomplete = addr_sd && (bvalid && bready);
// ar
assign arid    = 4'd0;
assign araddr  = addr_reg;
assign arlen   = 8'd0;
assign arsize  = size_reg;
assign arburst = 2'b01;
assign arlock  = 2'b00;
assign arcache = 4'd0;
assign arprot  = 3'd0;
assign arvalid = req_reg && ~wr_reg && ~addr_sd;
// 当addr_sd 为有效时，将
//r
assign rready  = 1'b1;
//aw
assign awid    = 4'd0;
assign awaddr  = addr_reg;
assign awlen   = 8'd0;
assign awsize  = size_reg;
assign awburst = 2'b01;
assign awlock  = 2'd0;
assign awcache = 4'd0;
assign awprot  = 3'd0;

assign awvalid = req_reg & wr_reg && ~addr_sd;

//w
assign wid     = 4'd0;
assign wdata   = wdata_reg;
assign wstrb   = wen_reg;
assign wlast   = 1'b1;
assign wvalid  = req_reg && wr_reg && ~wdata_sd;

//b
assign bready  = 1'b1;
endmodule

