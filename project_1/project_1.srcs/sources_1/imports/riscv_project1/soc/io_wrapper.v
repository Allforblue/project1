//-----------------------------------------------------------------
// Module:  Peripheral IO Wrapper (Aggregator)
// Address: 0xFFFFFC00 - 0xFFFFFCFF (256 Bytes)
//-----------------------------------------------------------------

module peripheral_io_wrapper
(
    // Clocks and Reset
     input          clk_i
    ,input          rst_i

    // AXI4-Lite Slave Interface (连接到 SoC 总线)
    ,input          cfg_awvalid_i
    ,input  [31:0]  cfg_awaddr_i
    ,input          cfg_wvalid_i
    ,input  [31:0]  cfg_wdata_i
    ,input  [3:0]   cfg_wstrb_i
    ,input          cfg_bready_i
    ,input          cfg_arvalid_i
    ,input  [31:0]  cfg_araddr_i
    ,input          cfg_rready_i

    ,output reg     cfg_awready_o
    ,output reg     cfg_wready_o
    ,output reg     cfg_bvalid_o
    ,output reg [1:0] cfg_bresp_o
    ,output reg     cfg_arready_o
    ,output reg     cfg_rvalid_o
    ,output reg [31:0] cfg_rdata_o
    ,output reg [1:0] cfg_rresp_o

    // --- External IO Ports (汇总所有子模块的 IO) ---
    // 1. Digits
    ,output [7:0]   digits_sel_o
    ,output [7:0]   digits_seg_o
    // 2. Keyboard
    ,input  [3:0]   keyboard_col_i
    ,output [3:0]   keyboard_row_o
    // 3. PWM
    ,output         pwm_o
    // 4. Watchdog
    ,output         wdt_reset_o
    // 5. LEDs
    ,output [15:0]  led_o
    // 6. Switches
    ,input  [15:0]  switch_i
);

    //-----------------------------------------------------------------
    // Address Decoding (Address Map)
    //-----------------------------------------------------------------
    // Offsets based on 0xFFFFFCxx
    localparam ADDR_DIGITS   = 8'h00; // Covers 0x00 - 0x0F
    localparam ADDR_KEYBOARD = 8'h10; // Covers 0x10 - 0x1F
    localparam ADDR_PWM      = 8'h30; // Covers 0x30 - 0x3F
    localparam ADDR_WDT      = 8'h50; // Covers 0x50 - 0x5F
    localparam ADDR_LEDS     = 8'h60; // Covers 0x60 - 0x6F
    localparam ADDR_SWITCHES = 8'h70; // Covers 0x70 - 0x7F

    // Chip Select Signals
    // Write Decode
    wire [7:0] wr_addr_offset = cfg_awaddr_i[7:0];
    wire sel_wr_digits   = (wr_addr_offset >= ADDR_DIGITS   && wr_addr_offset < 8'h10);
    wire sel_wr_keyboard = (wr_addr_offset >= ADDR_KEYBOARD && wr_addr_offset < 8'h20);
    wire sel_wr_pwm      = (wr_addr_offset >= ADDR_PWM      && wr_addr_offset < 8'h40); // 0x30, 0x34
    wire sel_wr_wdt      = (wr_addr_offset >= ADDR_WDT      && wr_addr_offset < 8'h60);
    wire sel_wr_leds     = (wr_addr_offset >= ADDR_LEDS     && wr_addr_offset < 8'h70);
    wire sel_wr_switches = (wr_addr_offset >= ADDR_SWITCHES && wr_addr_offset < 8'h80);

    // Read Decode
    wire [7:0] rd_addr_offset = cfg_araddr_i[7:0];
    wire sel_rd_digits   = (rd_addr_offset >= ADDR_DIGITS   && rd_addr_offset < 8'h10);
    wire sel_rd_keyboard = (rd_addr_offset >= ADDR_KEYBOARD && rd_addr_offset < 8'h20);
    wire sel_rd_pwm      = (rd_addr_offset >= ADDR_PWM      && rd_addr_offset < 8'h40);
    wire sel_rd_wdt      = (rd_addr_offset >= ADDR_WDT      && rd_addr_offset < 8'h60);
    wire sel_rd_leds     = (rd_addr_offset >= ADDR_LEDS     && rd_addr_offset < 8'h70);
    wire sel_rd_switches = (rd_addr_offset >= ADDR_SWITCHES && rd_addr_offset < 8'h80);

    //-----------------------------------------------------------------
    // Sub-module Instantiations
    //-----------------------------------------------------------------
    
    // Internal Wiring
    // (Defining wires to capture outputs from sub-modules)
    // We only need to define wires for AXI outputs (ready, rdata, etc.)
    // Inputs to sub-modules are broadcasted or gated.
    
    // 1. Digits
    wire dig_awready, dig_wready, dig_bvalid, dig_arready, dig_rvalid;
    wire [31:0] dig_rdata;
    
    peripheral_digits u_digits (
        .clk_i(clk_i), .rst_i(rst_i),
        // Gated Valid Inputs
        .cfg_awvalid_i(cfg_awvalid_i & sel_wr_digits),
        .cfg_wvalid_i (cfg_wvalid_i  & sel_wr_digits),
        .cfg_arvalid_i(cfg_arvalid_i & sel_rd_digits),
        // Broadcast Inputs
        .cfg_awaddr_i(cfg_awaddr_i), .cfg_wdata_i(cfg_wdata_i), .cfg_wstrb_i(cfg_wstrb_i),
        .cfg_bready_i(cfg_bready_i), .cfg_araddr_i(cfg_araddr_i), .cfg_rready_i(cfg_rready_i),
        // Outputs
        .cfg_awready_o(dig_awready), .cfg_wready_o(dig_wready), .cfg_bvalid_o(dig_bvalid),
        .cfg_arready_o(dig_arready), .cfg_rvalid_o(dig_rvalid), .cfg_rdata_o(dig_rdata),
        // IO
        .digits_sel_o(digits_sel_o), .digits_seg_o(digits_seg_o)
    );

    // 2. Keyboard
    wire key_awready, key_wready, key_bvalid, key_arready, key_rvalid;
    wire [31:0] key_rdata;

    peripheral_keyboard u_keyboard (
        .clk_i(clk_i), .rst_i(rst_i),
        .cfg_awvalid_i(cfg_awvalid_i & sel_wr_keyboard),
        .cfg_wvalid_i (cfg_wvalid_i  & sel_wr_keyboard),
        .cfg_arvalid_i(cfg_arvalid_i & sel_rd_keyboard),
        .cfg_awaddr_i(cfg_awaddr_i), .cfg_wdata_i(cfg_wdata_i), .cfg_wstrb_i(cfg_wstrb_i),
        .cfg_bready_i(cfg_bready_i), .cfg_araddr_i(cfg_araddr_i), .cfg_rready_i(cfg_rready_i),
        .cfg_awready_o(key_awready), .cfg_wready_o(key_wready), .cfg_bvalid_o(key_bvalid),
        .cfg_arready_o(key_arready), .cfg_rvalid_o(key_rvalid), .cfg_rdata_o(key_rdata),
        // IO
        .keyboard_col_i(keyboard_col_i), .keyboard_row_o(keyboard_row_o)
    );

    // 3. PWM
    wire pwm_awready, pwm_wready, pwm_bvalid, pwm_arready, pwm_rvalid;
    wire [31:0] pwm_rdata;

    peripheral_pwm u_pwm (
        .clk_i(clk_i), .rst_i(rst_i),
        .cfg_awvalid_i(cfg_awvalid_i & sel_wr_pwm),
        .cfg_wvalid_i (cfg_wvalid_i  & sel_wr_pwm),
        .cfg_arvalid_i(cfg_arvalid_i & sel_rd_pwm),
        .cfg_awaddr_i(cfg_awaddr_i), .cfg_wdata_i(cfg_wdata_i), .cfg_wstrb_i(cfg_wstrb_i),
        .cfg_bready_i(cfg_bready_i), .cfg_araddr_i(cfg_araddr_i), .cfg_rready_i(cfg_rready_i),
        .cfg_awready_o(pwm_awready), .cfg_wready_o(pwm_wready), .cfg_bvalid_o(pwm_bvalid),
        .cfg_arready_o(pwm_arready), .cfg_rvalid_o(pwm_rvalid), .cfg_rdata_o(pwm_rdata),
        // IO
        .pwm_o(pwm_o)
    );

    // 4. Watchdog
    wire wdt_awready, wdt_wready, wdt_bvalid, wdt_arready, wdt_rvalid;
    wire [31:0] wdt_rdata;

    peripheral_watchdog u_wdt (
        .clk_i(clk_i), .rst_i(rst_i),
        .cfg_awvalid_i(cfg_awvalid_i & sel_wr_wdt),
        .cfg_wvalid_i (cfg_wvalid_i  & sel_wr_wdt),
        .cfg_arvalid_i(cfg_arvalid_i & sel_rd_wdt),
        .cfg_awaddr_i(cfg_awaddr_i), .cfg_wdata_i(cfg_wdata_i), .cfg_wstrb_i(cfg_wstrb_i),
        .cfg_bready_i(cfg_bready_i), .cfg_araddr_i(cfg_araddr_i), .cfg_rready_i(cfg_rready_i),
        .cfg_awready_o(wdt_awready), .cfg_wready_o(wdt_wready), .cfg_bvalid_o(wdt_bvalid),
        .cfg_arready_o(wdt_arready), .cfg_rvalid_o(wdt_rvalid), .cfg_rdata_o(wdt_rdata),
        // IO
        .wdt_reset_o(wdt_reset_o)
    );

    // 5. LEDs
    wire led_awready, led_wready, led_bvalid, led_arready, led_rvalid;
    wire [31:0] led_rdata;

    peripheral_leds u_leds (
        .clk_i(clk_i), .rst_i(rst_i),
        .cfg_awvalid_i(cfg_awvalid_i & sel_wr_leds),
        .cfg_wvalid_i (cfg_wvalid_i  & sel_wr_leds),
        .cfg_arvalid_i(cfg_arvalid_i & sel_rd_leds),
        .cfg_awaddr_i(cfg_awaddr_i), .cfg_wdata_i(cfg_wdata_i), .cfg_wstrb_i(cfg_wstrb_i),
        .cfg_bready_i(cfg_bready_i), .cfg_araddr_i(cfg_araddr_i), .cfg_rready_i(cfg_rready_i),
        .cfg_awready_o(led_awready), .cfg_wready_o(led_wready), .cfg_bvalid_o(led_bvalid),
        .cfg_arready_o(led_arready), .cfg_rvalid_o(led_rvalid), .cfg_rdata_o(led_rdata),
        // IO
        .led_o(led_o)
    );

    // 6. Switches
    wire sw_awready, sw_wready, sw_bvalid, sw_arready, sw_rvalid;
    wire [31:0] sw_rdata;

    peripheral_switches u_switches (
        .clk_i(clk_i), .rst_i(rst_i),
        .cfg_awvalid_i(cfg_awvalid_i & sel_wr_switches),
        .cfg_wvalid_i (cfg_wvalid_i  & sel_wr_switches),
        .cfg_arvalid_i(cfg_arvalid_i & sel_rd_switches),
        .cfg_awaddr_i(cfg_awaddr_i), .cfg_wdata_i(cfg_wdata_i), .cfg_wstrb_i(cfg_wstrb_i),
        .cfg_bready_i(cfg_bready_i), .cfg_araddr_i(cfg_araddr_i), .cfg_rready_i(cfg_rready_i),
        .cfg_awready_o(sw_awready), .cfg_wready_o(sw_wready), .cfg_bvalid_o(sw_bvalid),
        .cfg_arready_o(sw_arready), .cfg_rvalid_o(sw_rvalid), .cfg_rdata_o(sw_rdata),
        // IO
        .switch_i(switch_i)
    );

    //-----------------------------------------------------------------
    // Response Mux (Multiplexer)
    //-----------------------------------------------------------------
    // 根据片选信号，将子模块的输出路由回 SoC 总线
    
    // Write Response Mux
    always @(*) begin
        if (sel_wr_digits) begin
            cfg_awready_o = dig_awready; cfg_wready_o = dig_wready; cfg_bvalid_o = dig_bvalid;
        end else if (sel_wr_keyboard) begin
            cfg_awready_o = key_awready; cfg_wready_o = key_wready; cfg_bvalid_o = key_bvalid;
        end else if (sel_wr_pwm) begin
            cfg_awready_o = pwm_awready; cfg_wready_o = pwm_wready; cfg_bvalid_o = pwm_bvalid;
        end else if (sel_wr_wdt) begin
            cfg_awready_o = wdt_awready; cfg_wready_o = wdt_wready; cfg_bvalid_o = wdt_bvalid;
        end else if (sel_wr_leds) begin
            cfg_awready_o = led_awready; cfg_wready_o = led_wready; cfg_bvalid_o = led_bvalid;
        end else if (sel_wr_switches) begin
            cfg_awready_o = sw_awready;  cfg_wready_o = sw_wready;  cfg_bvalid_o = sw_bvalid;
        end else begin
            // Address hole: respond with error or ignore (here: ignore/hang safely)
            cfg_awready_o = 1'b0; cfg_wready_o = 1'b0; cfg_bvalid_o = 1'b0;
        end
        cfg_bresp_o = 2'b00; // OKAY
    end

    // Read Response Mux
    always @(*) begin
        if (sel_rd_digits) begin
            cfg_arready_o = dig_arready; cfg_rvalid_o = dig_rvalid; cfg_rdata_o = dig_rdata;
        end else if (sel_rd_keyboard) begin
            cfg_arready_o = key_arready; cfg_rvalid_o = key_rvalid; cfg_rdata_o = key_rdata;
        end else if (sel_rd_pwm) begin
            cfg_arready_o = pwm_arready; cfg_rvalid_o = pwm_rvalid; cfg_rdata_o = pwm_rdata;
        end else if (sel_rd_wdt) begin
            cfg_arready_o = wdt_arready; cfg_rvalid_o = wdt_rvalid; cfg_rdata_o = wdt_rdata;
        end else if (sel_rd_leds) begin
            cfg_arready_o = led_arready; cfg_rvalid_o = led_rvalid; cfg_rdata_o = led_rdata;
        end else if (sel_rd_switches) begin
            cfg_arready_o = sw_arready;  cfg_rvalid_o = sw_rvalid;  cfg_rdata_o = sw_rdata;
        end else begin
            cfg_arready_o = 1'b0; cfg_rvalid_o = 1'b0; cfg_rdata_o = 32'b0;
        end
        cfg_rresp_o = 2'b00; // OKAY
    end

endmodule