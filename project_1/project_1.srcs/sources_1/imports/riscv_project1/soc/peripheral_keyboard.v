//-----------------------------------------------------------------
// Module:  4x4 Matrix Keyboard Peripheral (AXI4-Lite Wrapper)
// Origin:  Modified from keyboard.v for RISC-V Test SoC
// Address: Base + 0x10 (Physical: 0xFFFFFC10)
//-----------------------------------------------------------------

module peripheral_keyboard
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

    // Peripheral Specific IO
    ,input  [3:0]   keyboard_col_i // 列输入 (Cols)
    ,output reg [3:0] keyboard_row_o // 行输出 (Rows)
);

//-----------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------
localparam KEYBOARD_REG_OFFSET = 8'h10; // 0xFFFFFC10

// 状态机状态定义
localparam STATE_NO_KEY         = 4'd0;
localparam STATE_MIGHT_HAVE_KEY = 4'd1;
localparam STATE_SCAN_ROW0      = 4'd2;
localparam STATE_SCAN_ROW1      = 4'd3;
localparam STATE_SCAN_ROW2      = 4'd4;
localparam STATE_SCAN_ROW3      = 4'd5;

// 防抖计数 (假设 SoC 时钟较快，可能需要调整此值)
localparam DEBOUNCE_COUNT = 20000; 

//-----------------------------------------------------------------
// Internal Signals
//-----------------------------------------------------------------
reg [3:0]  state_q;
reg [15:0] count_q;
reg [31:0] key_data_q; // 存储按键值的寄存器

//-----------------------------------------------------------------
// AXI Request Logic
//-----------------------------------------------------------------
wire read_en_w  = cfg_arvalid_i & cfg_arready_o;
wire write_en_w = cfg_awvalid_i & cfg_awready_o; // 键盘通常只读，但也需要响应写握手

//-----------------------------------------------------------------
// AXI Accept Logic
//-----------------------------------------------------------------
assign cfg_arready_o = ~cfg_rvalid_o;
assign cfg_awready_o = ~cfg_bvalid_o && ~cfg_arvalid_i; 
assign cfg_wready_o  = cfg_awready_o;

//-----------------------------------------------------------------
// Keyboard Scanning Logic (State Machine)
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        state_q        <= STATE_NO_KEY;
        keyboard_row_o <= 4'b0000;
        count_q        <= 16'd0;
        key_data_q     <= 32'hffffffff; // 默认无按键值
    end else begin
        case (state_q)
            STATE_NO_KEY: begin
                keyboard_row_o <= 4'b0000; // 拉低所有行，准备检测列
                count_q        <= 16'd0;
                // 若列不全为1（有键按下），进入消抖
                if (keyboard_col_i != 4'b1111) begin
                    state_q <= STATE_MIGHT_HAVE_KEY;
                end
            end 

            STATE_MIGHT_HAVE_KEY: begin
                if (count_q != DEBOUNCE_COUNT) begin
                    count_q <= count_q + 16'd1;
                end else if (keyboard_col_i == 4'b1111) begin
                    // 抖动或误触，返回
                    state_q <= STATE_NO_KEY;
                    count_q <= 16'd0;
                end else begin
                    // 确认按下，开始逐行扫描
                    keyboard_row_o <= 4'b1110; // 扫描行 0
                    state_q        <= STATE_SCAN_ROW0;
                end
            end

            STATE_SCAN_ROW0: begin
                if (keyboard_col_i == 4'b1111) begin
                    // 没在行0检测到
                    keyboard_row_o <= 4'b1101; // 准备扫行 1
                    state_q        <= STATE_SCAN_ROW1;
                end else begin
                    // 在行0检测到了
                    state_q <= STATE_NO_KEY;
                    case (keyboard_col_i)
                        4'b1110: key_data_q <= 32'd13;
                        4'b1101: key_data_q <= 32'd12;
                        4'b1011: key_data_q <= 32'd11;
                        4'b0111: key_data_q <= 32'd10;
                        default: key_data_q <= 32'hffffffff;
                    endcase
                end   
            end

            STATE_SCAN_ROW1: begin
                if (keyboard_col_i == 4'b1111) begin
                    keyboard_row_o <= 4'b1011; // 准备扫行 2
                    state_q        <= STATE_SCAN_ROW2;
                end else begin
                    state_q <= STATE_NO_KEY;
                    case (keyboard_col_i)
                        4'b1110: key_data_q <= 32'd15;
                        4'b1101: key_data_q <= 32'd9;
                        4'b1011: key_data_q <= 32'd6;
                        4'b0111: key_data_q <= 32'd3;
                        default: key_data_q <= 32'hffffffff;
                    endcase
                end           
            end

            STATE_SCAN_ROW2: begin
                if (keyboard_col_i == 4'b1111) begin
                    keyboard_row_o <= 4'b0111; // 准备扫行 3
                    state_q        <= STATE_SCAN_ROW3;
                end else begin
                    state_q <= STATE_NO_KEY;
                    case (keyboard_col_i)
                        4'b1110: key_data_q <= 32'd0;
                        4'b1101: key_data_q <= 32'd8;
                        4'b1011: key_data_q <= 32'd5;
                        4'b0111: key_data_q <= 32'd2;
                        default: key_data_q <= 32'hffffffff;
                    endcase
                end          
            end

            STATE_SCAN_ROW3: begin
                // 无论是否检测到，都要回初始状态了
                if (keyboard_col_i == 4'b1111) begin
                    keyboard_row_o <= 4'b0000;
                    state_q        <= STATE_NO_KEY;
                end else begin
                    state_q <= STATE_NO_KEY;
                    case (keyboard_col_i)
                        4'b1110: key_data_q <= 32'd14;
                        4'b1101: key_data_q <= 32'd7;
                        4'b1011: key_data_q <= 32'd4;
                        4'b0111: key_data_q <= 32'd1;
                        default: key_data_q <= 32'hffffffff;
                    endcase
                end           
            end
            
            default: state_q <= STATE_NO_KEY;
        endcase
    end
end

//-----------------------------------------------------------------
// Read Logic
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ * begin
    data_r = 32'b0;
    // 读地址匹配
    if (cfg_araddr_i[7:0] == KEYBOARD_REG_OFFSET) begin
        data_r = key_data_q;
    end
end

//-----------------------------------------------------------------
// AXI Responses (Standard)
//-----------------------------------------------------------------
// Read Valid Generation
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

// Write Valid Generation (Dummy Write - Keyboard is Read Only)
// 虽然是只读，但必须响应写握手，否则会卡死总线
reg bvalid_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i) bvalid_q <= 1'b0;
else if (write_en_w) bvalid_q <= 1'b1;
else if (cfg_bready_i) bvalid_q <= 1'b0;

assign cfg_bvalid_o = bvalid_q;
assign cfg_bresp_o  = 2'b0; // OKAY response

endmodule