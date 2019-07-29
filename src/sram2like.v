/*************************************************************************
    > Filename: sram2like.v
    > Author: Lv Feng
    > Mail: lvfeng97@outlook.com
    > Date: 2017-12-04
 ************************************************************************/
//  sram 向 类sram 接口的转化
module sram2like(
	input  wire        clk,
	input  wire        resetn,
	input  wire [5 :0] tlb_exce,

	output wire        stall,

	input  wire        inst_sram_en, // 恒为1，读取
	input  wire [ 3:0] inst_sram_wen,// 恒为0， 仅读取数据
	input  wire [31:0] inst_sram_addr,
	input  wire [31:0] inst_sram_wdata, //恒为0 ，仅读取
	// output
	output wire [31:0] inst_sram_rdata, // 根据地址得到的

	input  wire        data_sram_en,
	input  wire [ 3:0] data_sram_wen, //写字节使能
	input  wire [31:0] data_sram_addr,
	input  wire [31:0] data_sram_wdata,
	// output
	output wire [31:0] data_sram_rdata, //从外设获取data值，？？？？ 

	output wire        inst_req,
	// 入射
	output wire        inst_wr, // 恒为0， 仅读取数据
	output wire [1 :0] inst_size,
	output wire [31:0] inst_addr,
	output wire [31:0] inst_wdata,
	// input
    input  wire [31:0] inst_rdata,
    input  wire        inst_addr_ok,
    input  wire        inst_data_ok,

    output wire        data_req, // data_ram 的请求状态
    output wire        data_wr,  // 写使能
    output wire [1 :0] data_size,//写字节数目
    output wire [31:0] data_addr,// 共同控制传输数据的字节数
	output wire [31:0] data_wdata,  
	// input
    input  wire [31:0] data_rdata,
	// 写地址，写数据握手信号
    input  wire        data_addr_ok,
    input  wire        data_data_ok 
);

assign inst_wr = |inst_sram_wen; 
assign inst_size = 2'b10;
assign inst_wdata = inst_sram_wdata;

reg         inst_en, data_en;
reg         data_wen;
reg         inst_aok, data_aok;
reg  [31:0] inst_areg, data_areg;
reg  [31:0] inst_dreg, data_dreg;
reg  [31:0] data_data_reg;
reg  [ 1:0] data_size_reg;
reg  [ 1:0] data_addr_reg;
wire [ 2:0] wnum;


always @(posedge clk)
begin
	if (resetn)
	begin
	// inst 使能
		inst_en <= (inst_data_ok && inst_aok && inst_en)?1'b0 : 
				   (inst_sram_en)? 1'b1 : inst_en; //inst_sram_en;
	// inst_address reg 
		inst_areg <= (inst_data_ok && inst_aok && inst_en)?32'd0 : 
					 (inst_sram_en)?inst_sram_addr : inst_areg; //inst_sram_addr;
	// inst_date reg 
		inst_dreg <= (inst_data_ok && inst_en)?inst_sram_rdata : inst_dreg;
	//  data en
		data_en <= (data_data_ok && data_en)?1'b0 : data_sram_en;
	// data_address
		data_areg <= (data_data_ok && data_en)?32'd0 : data_sram_addr;
	// data_data 
		data_dreg <= (data_data_ok && data_en)?data_rdata : data_dreg;
	// data_sram 的 写使能
		data_wen <= (data_data_ok && data_wen && data_en)?1'b0: |data_sram_wen;
		
	// wnum 表示写字节的数目 
		data_size_reg <= (2'b00 & {2{wnum == 3'd1}}) |
						 (2'b01 & {2{wnum == 3'd2}} ) |
						 (2'b10 & {2{wnum == 3'd3 || wnum == 3'd4}});
		data_addr_reg <= (2'b00 & {2{(wnum == 3'd1 && data_sram_wen[0]) || (wnum == 3'd2 && data_sram_wen[0]) || (wnum == 3'd4)}}) |
						 (2'b01 & {2{(wnum == 3'd1 && data_sram_wen[1]) || (wnum == 3'd3 && data_sram_wen[3])}}) |
						 (2'b11 & {2{wnum == 3'd1 && data_sram_wen[3]}});
		data_data_reg <= (data_data_ok && data_wen) ? 32'd0 : data_sram_wdata;
		// inst_ram inst_answer_ok inst响应请求
		inst_aok <= (inst_aok && inst_data_ok)? 1'b0 :
					(inst_en && inst_addr_ok)? 1'b1 : inst_aok;
		// data_ram 响应请	 data_answer_ok
		data_aok <= (data_aok && data_data_ok)? 1'b0 :
					(data_en && data_addr_ok)? 1'b1 : data_aok;
	end
	else 
	begin
		inst_en <= 1'b0;
		inst_areg <= 32'd0;
		data_en <= 1'b0;
		data_areg <= 32'd0;
		data_wen <= 1'b0;
		data_size_reg <= 2'b00;
		data_addr_reg <= 2'b00;
		data_data_reg <= 32'd0;
		inst_aok <= 1'b0;
		data_aok <= 1'b0;
	end
end

assign inst_req  = inst_en;
assign inst_addr = inst_areg;
assign inst_sram_rdata = (inst_en && inst_data_ok && inst_aok)?inst_rdata : 32'd0;

assign wnum = data_sram_wen[0] + data_sram_wen[1] + data_sram_wen[2] + data_sram_wen[3];
assign data_req = data_en;
assign data_wr = data_wen;
assign data_size = data_size_reg;
assign data_addr = {data_areg[31:2], data_addr_reg};
assign data_wdata = data_data_reg;
assign data_sram_rdata = (data_data_ok && data_sram_en && data_aok) ?data_rdata : data_dreg; 

assign stall = (~|tlb_exce && ((~(inst_aok && inst_data_ok) && inst_sram_en) || (~data_data_ok && data_sram_en)))? 1'b1 : 1'b0;
endmodule
