//-----------------------------------------------------------------
// Module:  PWM Peripheral (AXI4-Lite Wrapper)
// Origin:  Modified from pwm.v for RISC-V Test SoC
// Address: Base + 0x30 (Params), Base + 0x34 (Control)
// Physical Base: 0xFFFFFC30
//-----------------------------------------------------------------

module peripheral_pwm
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
    // [修改点]: 重命名为 pwm_o
    ,output reg     pwm_o
);

//-----------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------
// 寄存器地址偏移
localparam REG_PARAMS_OFFSET = 8'h30; // 0xFFFFFC30: {Compare[15:0], Threshold[15:0]}
localparam REG_CTRL_OFFSET   = 8'h34; // 0xFFFFFC34: Control

//-----------------------------------------------------------------
// Internal Registers
//-----------------------------------------------------------------
reg [15:0] threshold_q; // 最大值 (周期)
reg [15:0] compare_q;   // 对比值 (占空比)
reg [7:0]  ctrl_q;      // 控制寄存器
reg [15:0] count_q;     // 当前计数

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
    // 复位默认值 (参考原代码)
    threshold_q <= 16'hffff;
    compare_q   <= 16'h7fff; // ~50% 占空比
    ctrl_q      <= 8'd1;     // 默认开启
end
else if (write_en_w) begin
    // --- 寄存器 1: Params (0xFFFFFC30) ---
    // [重要]: 使用 wstrb 支持字节写入，允许单独修改 threshold 或 compare
    if (cfg_awaddr_i[7:0] == REG_PARAMS_OFFSET) begin
        // Threshold (低16位)
        if (cfg_wstrb_i[0]) threshold_q[7:0]   <= cfg_wdata_i[7:0];
        if (cfg_wstrb_i[1]) threshold_q[15:8]  <= cfg_wdata_i[15:8];
        
        // Compare (高16位)
        if (cfg_wstrb_i[2]) compare_q[7:0]     <= cfg_wdata_i[23:16];
        if (cfg_wstrb_i[3]) compare_q[15:8]    <= cfg_wdata_i[31:24];
    end
    
    // --- 寄存器 2: Control (0xFFFFFC34) ---
    else if (cfg_awaddr_i[7:0] == REG_CTRL_OFFSET) begin
        if (cfg_wstrb_i[0]) ctrl_q <= cfg_wdata_i[7:0];
    end
end

//-----------------------------------------------------------------
// Read Logic
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ *
begin
    data_r = 32'b0;
    
    case (cfg_araddr_i[7:0])
        REG_PARAMS_OFFSET: begin
            // 拼合 Compare 和 Threshold
            data_r = {compare_q, threshold_q};
        end
        REG_CTRL_OFFSET: begin
            data_r = {24'b0, ctrl_q};
        end
        default: begin
            data_r = 32'b0;
        end
    endcase
end

//-----------------------------------------------------------------
// PWM Core Logic
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
if (rst_i) begin
    count_q <= 16'd0;
    pwm_o   <= 1'b1;
end
else begin
    // 只有当控制寄存器 bit 0 为 1 时工作
    if (ctrl_q[0]) begin
        // 计数器逻辑
        if (count_q >= threshold_q) begin
            count_q <= 16'd0;
        end else begin
            count_q <= count_q + 16'd1;
        end

        // 比较输出逻辑 (High active when current <= compare)
        // 原代码逻辑: if (current > compare) result <= Disable (0); else result <= Enable (1);
        if (count_q > compare_q) begin
            pwm_o <= 1'b0;
        end else begin
            pwm_o <= 1'b1;
        end
    end 
    else begin
        // 禁用状态
        count_q <= 16'd0;
        pwm_o   <= 1'b0; 
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

// BVALID Generation
reg bvalid_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) bvalid_q <= 1'b0;
else if (write_en_w) bvalid_q <= 1'b1;
else if (cfg_bready_i) bvalid_q <= 1'b0;

assign cfg_bvalid_o = bvalid_q;
assign cfg_bresp_o  = 2'b0;

endmodule