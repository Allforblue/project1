//-----------------------------------------------------------------
// Module:  Watchdog Timer (AXI4-Lite Wrapper)
// Origin:  Modified from watchdog.v for RISC-V Test SoC
// Address: Base + 0x50 (Physical: 0xFFFFFC50)
//-----------------------------------------------------------------

module peripheral_watchdog
(
    // Clocks and Reset
     input          clk_i
    ,input          rst_i  // System Reset (Active High)

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

    // Watchdog Reset Output
    // [注意]: 该信号应连接到系统的复位控制器或与外部复位信号“或”在一起
    ,output reg     wdt_reset_o 
);

//-----------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------
localparam WDT_REG_OFFSET = 8'h50; 

// 默认超时周期。
// 假设时钟 50MHz，0x02FAF080 (50,000,000) 大约 1秒。
// 原代码 16位太短了，这里改为 32位。
localparam INITIAL_COUNT = 32'd50_000_000; 

//-----------------------------------------------------------------
// Internal Registers
//-----------------------------------------------------------------
reg [31:0] current_count;
reg [3:0]  reset_keeper; // 延长复位脉冲

//-----------------------------------------------------------------
// Request Logic
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
// Watchdog Logic
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        // 硬复位时，重置计数器，不触发 WDT 复位
        current_count <= INITIAL_COUNT;
        wdt_reset_o   <= 1'b0;
        reset_keeper  <= 4'd0;
    end
    else begin
        // 1. 喂狗检测 (Feed the dog)
        if (write_en_w && (cfg_awaddr_i[7:0] == WDT_REG_OFFSET)) begin
            // 只要有写入操作，就重置计数器 (不管写入什么值)
            // 也可以选择写入特定值(如 0x55AA)才喂狗，这里保持原逻辑简单
            current_count <= INITIAL_COUNT;
        end
        // 2. 倒计时逻辑
        else if (current_count > 0) begin
            current_count <= current_count - 1;
        end
        // 3. 超时触发
        else if (current_count == 0) begin
            // 计数器保持 0，直到复位发生
            current_count <= 0;
            // 启动复位保持计数器 (例如保持 15 个周期)
            reset_keeper  <= 4'b1111; 
        end

        // 4. 生成复位脉冲
        if (reset_keeper > 0) begin
            wdt_reset_o  <= 1'b1; // 触发复位
            reset_keeper <= reset_keeper - 4'd1;
        end else begin
            wdt_reset_o  <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------
// Read Logic
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ * begin
    data_r = 32'b0;
    // 允许读取当前计数值 (方便调试)
    if (cfg_araddr_i[7:0] == WDT_REG_OFFSET) begin
        data_r = current_count;
    end
end

//-----------------------------------------------------------------
// AXI Responses
//-----------------------------------------------------------------
reg rvalid_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) rvalid_q <= 1'b0;
else if (read_en_w) rvalid_q <= 1'b1;
else if (cfg_rready_i) rvalid_q <= 1'b0;

assign cfg_rvalid_o = rvalid_q;

reg [31:0] rd_data_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) rd_data_q <= 32'b0;
else if (!cfg_rvalid_o || cfg_rready_i) rd_data_q <= data_r;

assign cfg_rdata_o = rd_data_q;
assign cfg_rresp_o = 2'b0;

reg bvalid_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) bvalid_q <= 1'b0;
else if (write_en_w) bvalid_q <= 1'b1;
else if (cfg_bready_i) bvalid_q <= 1'b0;

assign cfg_bvalid_o = bvalid_q;
assign cfg_bresp_o  = 2'b0;

endmodule