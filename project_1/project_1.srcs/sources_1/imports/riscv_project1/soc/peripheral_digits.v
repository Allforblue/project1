//-----------------------------------------------------------------
// Module:  7-Segment Display Peripheral (AXI4-Lite Wrapper)
// Origin:  Modified from digits.v for RISC-V Test SoC
// Address: Base + 0x00 (Data/Decode), Base + 0x04 (Digit Select)
// Physical Base Example: 0xFFFFFC00
//-----------------------------------------------------------------

module peripheral_digits
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

    // Peripheral Specific Outputs
    // [修改点]: 使用特定前缀 digits_ 防止命名冲突
    ,output reg [7:0] digits_sel_o  // 位选信号 (Common Anode usually active low)
    ,output reg [7:0] digits_seg_o  // 段选信号 (DP, G, F, E, D, C, B, A)
);

//-----------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------
// 寄存器地址偏移定义
localparam REG_DATA_OFFSET = 8'h00; // 对应 0xFFFFFC00
localparam REG_SEL_OFFSET  = 8'h04; // 对应 0xFFFFFC04

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
    // 复位状态：共阳极数码管通常写1为灭，写0为亮
    // 初始状态全灭
    digits_sel_o <= 8'hff;
    digits_seg_o <= 8'hff;
end
else if (write_en_w) begin
    // --- 寄存器 1: 显示数据 (0xFFFFFC00) ---
    if (cfg_awaddr_i[7:0] == REG_DATA_OFFSET) begin
        case (cfg_wdata_i[7:0])
            //                DP_GFE_DCBA (Bit 7 to 0)
            8'd0:  digits_seg_o <= 8'b1100_0000; // 0: ABCDEF
            8'd1:  digits_seg_o <= 8'b1111_1001; // 1: BC
            8'd2:  digits_seg_o <= 8'b1010_0100; // 2: ABDEG
            8'd3:  digits_seg_o <= 8'b1011_0000; // 3: ABCDG
            8'd4:  digits_seg_o <= 8'b1001_1001; // 4: BCFG
            8'd5:  digits_seg_o <= 8'b1001_0010; // 5: ACDFG
            8'd6:  digits_seg_o <= 8'b1000_0010; // 6: ACDEFG
            8'd7:  digits_seg_o <= 8'b1111_1000; // 7: ABC
            8'd8:  digits_seg_o <= 8'b1000_0000; // 8: ABCDEFG
            8'd9:  digits_seg_o <= 8'b1001_1000; // 9: ABCFG
            8'd10: digits_seg_o <= 8'b1000_1000; // A: ABCEFG
            8'd11: digits_seg_o <= 8'b1000_0011; // b: CDEFG
            8'd12: digits_seg_o <= 8'b1010_0111; // C: DEG
            8'd13: digits_seg_o <= 8'b1010_0001; // d: BCDEG
            8'd14: digits_seg_o <= 8'b1000_0110; // E: ADEFG
            8'd15: digits_seg_o <= 8'b1000_1110; // F: AEFG
            8'd16: digits_seg_o <= 8'b1100_0001; // U: BCDEF
            8'd17: digits_seg_o <= 8'b1001_0001; // y: BCDFG
            default: digits_seg_o <= 8'b1111_1111; // Off
        endcase
    end
    
    // --- 寄存器 2: 位选控制 (0xFFFFFC04) ---
    else if (cfg_awaddr_i[7:0] == REG_SEL_OFFSET) begin
        // 原逻辑：传入 index (0-7)，输出 ~(1 << index)
        // 假设共阳极位选是低电平有效
        digits_sel_o <= ~(8'b1 << cfg_wdata_i[2:0]); 
    end
end

//-----------------------------------------------------------------
// Read Logic (Read Mux)
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ *
begin
    data_r = 32'b0;
    
    case (cfg_araddr_i[7:0])
        REG_DATA_OFFSET: begin
            data_r = {24'b0, digits_seg_o};
        end
        REG_SEL_OFFSET: begin
            data_r = {24'b0, digits_sel_o};
        end
        default: begin
            data_r = 32'b0;
        end
    endcase
end

//-----------------------------------------------------------------
// RVALID Generation
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
// BVALID Generation
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