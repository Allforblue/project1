//-----------------------------------------------------------------
// Module:  Switches Peripheral (AXI4-Lite Wrapper)
// Origin:  Modified from switches.v for RISC-V Test SoC
// Address: Base + 0x70 (Physical: 0xFFFFFC70)
// Type:    Read Only
//-----------------------------------------------------------------

module peripheral_switches
(
    // Clocks and Reset
     input          clk_i
    ,input          rst_i  // Active High Reset

    // AXI4-Lite Slave Interface
    ,input          cfg_awvalid_i
    ,input  [31:0]  cfg_awaddr_i
    ,input          cfg_wvalid_i
    ,input  [31:0]  cfg_wdata_i
    ,input  [3:0]   cfg_wstrb_i
    ,input          cfg_bready_i
    ,input          cfg_arvalid_i
    ,input  [31:0]  cfg_araddr_i
    ,input          cfg_rready_i

    // Outputs to Interconnect
    ,output         cfg_awready_o
    ,output         cfg_wready_o
    ,output         cfg_bvalid_o
    ,output [1:0]   cfg_bresp_o
    ,output         cfg_arready_o
    ,output         cfg_rvalid_o
    ,output [31:0]  cfg_rdata_o
    ,output [1:0]   cfg_rresp_o

    // Peripheral Specific Input
    // [修改点]: 重命名为 switch_i，明确这是输入信号
    ,input  [15:0]  switch_i
);

//-----------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------
// 寄存器地址偏移: 0xFFFFFC70
localparam SWITCHES_REG_OFFSET = 8'h70; 

//-----------------------------------------------------------------
// Internal Registers (Synchronization)
//-----------------------------------------------------------------
reg [15:0] switch_sync_1; // 第一级同步
reg [15:0] switch_sync_2; // 第二级同步 (稳定数据)

//-----------------------------------------------------------------
// Request Logic (Standard AXI-Lite Handshake)
//-----------------------------------------------------------------
wire read_en_w  = cfg_arvalid_i & cfg_arready_o;
wire write_en_w = cfg_awvalid_i & cfg_awready_o;

//-----------------------------------------------------------------
// Accept Logic
//-----------------------------------------------------------------
assign cfg_arready_o = ~cfg_rvalid_o;
assign cfg_awready_o = ~cfg_bvalid_o && ~cfg_arvalid_i; 
assign cfg_wready_o  = cfg_awready_o;

//-----------------------------------------------------------------
// Input Synchronization Logic
//-----------------------------------------------------------------
// 外部开关信号是异步的，必须同步到 SoC 时钟域
// 使用两级寄存器消除亚稳态
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        switch_sync_1 <= 16'd0;
        switch_sync_2 <= 16'd0;
    end else begin
        switch_sync_1 <= switch_i;      // 第一拍
        switch_sync_2 <= switch_sync_1; // 第二拍 (CPU 读取这个)
    end
end

//-----------------------------------------------------------------
// Write Logic (Dummy)
//-----------------------------------------------------------------
// 开关是只读设备，这里不执行任何写操作
// 但必须存在逻辑以响应总线握手，防止 hang 住
// always @ (posedge clk_i) ... do nothing

//-----------------------------------------------------------------
// Read Logic
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ *
begin
    data_r = 32'b0;
    
    // 读回经过同步的开关状态
    if (cfg_araddr_i[7:0] == SWITCHES_REG_OFFSET) begin
        // 高位补0，低16位为开关值
        data_r = {16'h0000, switch_sync_2};
    end
end

//-----------------------------------------------------------------
// AXI Responses (Standard)
//-----------------------------------------------------------------
// RVALID Generation
reg rvalid_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) rvalid_q <= 1'b0;
else if (read_en_w) rvalid_q <= 1'b1;
else if (cfg_rready_i) rvalid_q <= 1'b0;

assign cfg_rvalid_o = rvalid_q;

// Read Data Output
reg [31:0] rd_data_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) rd_data_q <= 32'b0;
else if (!cfg_rvalid_o || cfg_rready_i) rd_data_q <= data_r;

assign cfg_rdata_o = rd_data_q;
assign cfg_rresp_o = 2'b0;

// BVALID Generation (Write Response)
reg bvalid_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) bvalid_q <= 1'b0;
else if (write_en_w) bvalid_q <= 1'b1;
else if (cfg_bready_i) bvalid_q <= 1'b0;

assign cfg_bvalid_o = bvalid_q;
assign cfg_bresp_o  = 2'b0; // OKAY response (即使没写入，也告诉CPU操作完成)

endmodule