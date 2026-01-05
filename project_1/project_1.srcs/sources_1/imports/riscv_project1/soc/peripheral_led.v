//-----------------------------------------------------------------
// Module:  LEDs Peripheral (AXI4-Lite Wrapper)
// Origin:  Modified from leds.v for RISC-V Test SoC
// Address: Base + 0x60 (Physical: 0xFFFFFC60)
//-----------------------------------------------------------------

module peripheral_leds
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
    // [修改点]: 重命名为 led_o 以区分其他外设
    ,output reg [15:0] led_o
);

//-----------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------
// 寄存器地址偏移: 0xFFFFFC60
localparam LEDS_REG_OFFSET = 8'h60; 

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
    // [逻辑保持]: 复位值为 16'h0101
    led_o <= 16'h0101;
end
else if (write_en_w) begin
    // 检查地址偏移是否为 0x60
    if (cfg_awaddr_i[7:0] == LEDS_REG_OFFSET) begin
        // 更新 LED 状态，只取低16位
        led_o <= cfg_wdata_i[15:0];
    end
end

//-----------------------------------------------------------------
// Read Logic
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ *
begin
    data_r = 32'b0;
    
    // 读回当前 LED 状态
    if (cfg_araddr_i[7:0] == LEDS_REG_OFFSET) begin
        data_r = {16'h0000, led_o};
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