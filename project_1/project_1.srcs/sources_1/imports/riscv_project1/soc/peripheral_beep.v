//-----------------------------------------------------------------
// Module:  Buzzer Peripheral (AXI4-Lite Wrapper)
// Origin:  Modified from beep.v for RISC-V Test SoC
// Address: Base + 0x10 (Physical: 0xFFFFFD10)
// Base:0xFFFFFD00
//-----------------------------------------------------------------

module beep
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

    // Peripheral Specific Output
    // [修改点]: 将 signal_out 改为 buzzer_o，明确这是蜂鸣器输出
    ,output reg     buzzer_o
);

//-----------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------
// 假设外设基地址为 0xFFFFFD00，则寄存器偏移为 0x10
localparam BUZZER_REG_OFFSET = 8'h10; 

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
// Write Logic
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
if (rst_i) begin
    buzzer_o <= 1'b0; // 复位时关闭蜂鸣器
end
else if (write_en_w) begin
    // 检查地址低8位是否匹配 0x10
    if (cfg_awaddr_i[7:0] == BUZZER_REG_OFFSET) begin
        // [逻辑保持不变]: 只要写入数据不为0，输出高电平
        // 这里使用了缩减或运算符 |，只要 cfg_wdata_i 任意一位为1，结果即为1
        buzzer_o <= |cfg_wdata_i; 
    end
end

//-----------------------------------------------------------------
// Read Logic (Read Mux)
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ *
begin
    data_r = 32'b0;
    
    // 检查地址低8位是否匹配 0x10
    if (cfg_araddr_i[7:0] == BUZZER_REG_OFFSET) begin
        // [修改点]: 读取时返回 buzzer_o 的状态
        data_r = {31'b0, buzzer_o};
    end
end

//-----------------------------------------------------------------
// RVALID Generation (Read Response Valid)
//-----------------------------------------------------------------
reg rvalid_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    rvalid_q <= 1'b0;
else if (read_en_w)
    rvalid_q <= 1'b1;
else if (cfg_rready_i)
    rvalid_q <= 1'b0;

assign cfg_rvalid_o = rvalid_q;

//-----------------------------------------------------------------
// Read Data Output
//-----------------------------------------------------------------
reg [31:0] rd_data_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    rd_data_q <= 32'b0;
else if (!cfg_rvalid_o || cfg_rready_i)
    rd_data_q <= data_r;

assign cfg_rdata_o = rd_data_q;
assign cfg_rresp_o = 2'b0; // OKAY response

//-----------------------------------------------------------------
// BVALID Generation (Write Response Valid)
//-----------------------------------------------------------------
reg bvalid_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    bvalid_q <= 1'b0;
else if (write_en_w)
    bvalid_q <= 1'b1;
else if (cfg_bready_i)
    bvalid_q <= 1'b0;

assign cfg_bvalid_o = bvalid_q;
assign cfg_bresp_o  = 2'b0; // OKAY response

endmodule