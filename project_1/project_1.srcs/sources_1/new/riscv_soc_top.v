//-----------------------------------------------------------------
// 模块名称: riscv_soc_top
// 功能描述: 集成 RISC-V 内核(带TCM)与 SoC 外设子系统
//-----------------------------------------------------------------
module riscv_soc_top
#(
     parameter BOOT_VECTOR        = 32'h00002000
    ,parameter TCM_MEM_BASE       = 32'h00000000
)
(
    // 基础系统接口
     input           clk_i
    ,input           rst_i        // 全局复位
    ,input           rst_cpu_i    // CPU独立复位（建议：加载程序时拉高，加载完拉低）

    // 外部加载接口 (AXI Target - 用于通过外部把程序载入TCM)
    ,input           axi_t_awvalid_i
    ,input  [ 31:0]  axi_t_awaddr_i
    ,input  [  3:0]  axi_t_awid_i
    ,input  [  7:0]  axi_t_awlen_i
    ,input  [  1:0]  axi_t_awburst_i
    ,input           axi_t_wvalid_i
    ,input  [ 31:0]  axi_t_wdata_i
    ,input  [  3:0]  axi_t_wstrb_i
    ,input           axi_t_wlast_i
    ,input           axi_t_bready_i
    ,input           axi_t_arvalid_i
    ,input  [ 31:0]  axi_t_araddr_i
    ,input  [  3:0]  axi_t_arid_i
    ,input  [  7:0]  axi_t_arlen_i
    ,input  [  1:0]  axi_t_arburst_i
    ,input           axi_t_rready_i
    ,output          axi_t_awready_o
    ,output          axi_t_wready_o
    ,output          axi_t_bvalid_o
    ,output [  1:0]  axi_t_bresp_o
    ,output [  3:0]  axi_t_bid_o
    ,output          axi_t_arready_o
    ,output          axi_t_rvalid_o
    ,output [ 31:0]  axi_t_rdata_o
    ,output [  1:0]  axi_t_rresp_o
    ,output [  3:0]  axi_t_rid_o
    ,output          axi_t_rlast_o

    // 外设物理引脚
    ,input           uart_rx_i    // UART 接收
    ,output          uart_tx_o    // UART 发送
    ,input           spi_miso_i
    ,output          spi_mosi_o
    ,output          spi_clk_o
    ,output          spi_cs_o
    ,input  [ 31:0]  gpio_in_i    // 连按键、拨码开关等
    ,output [ 31:0]  gpio_out_o   // 连LED、数码管等
);

//-----------------------------------------------------------------
// 内部信号线 (CPU Master -> SoC Slave)
//-----------------------------------------------------------------
wire        cpu_axi_awvalid;
wire [31:0] cpu_axi_awaddr;
wire        cpu_axi_wvalid;
wire [31:0] cpu_axi_wdata;
wire [3:0]  cpu_axi_wstrb;
wire        cpu_axi_bready;
wire        cpu_axi_arvalid;
wire [31:0] cpu_axi_araddr;
wire        cpu_axi_rready;

wire        soc_axi_awready;
wire        soc_axi_wready;
wire        soc_axi_bvalid;
wire [1:0]  soc_axi_bresp;
wire        soc_axi_arready;
wire        soc_axi_rvalid;
wire [31:0] soc_axi_rdata;
wire [1:0]  soc_axi_rresp;

wire        soc_intr_w;

//-----------------------------------------------------------------
// 1. 实例化 RISC-V 内核与 TCM 系统
//-----------------------------------------------------------------
riscv_tcm_top #(
    .BOOT_VECTOR(BOOT_VECTOR),
    .TCM_MEM_BASE(TCM_MEM_BASE)
) u_riscv (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .rst_cpu_i(rst_cpu_i),
    .intr_i({31'b0, soc_intr_w}), // 接收来自 SoC 的中断信号

    // AXI Master 接口 (访问外设)
    .axi_i_awvalid_o(cpu_axi_awvalid),
    .axi_i_awaddr_o (cpu_axi_awaddr),
    .axi_i_awready_i(soc_axi_awready),
    .axi_i_wvalid_o (cpu_axi_wvalid),
    .axi_i_wdata_o  (cpu_axi_wdata),
    .axi_i_wstrb_o  (cpu_axi_wstrb),
    .axi_i_wready_i (soc_axi_wready),
    .axi_i_bvalid_i (soc_axi_bvalid),
    .axi_i_bresp_i  (soc_axi_bresp),
    .axi_i_bready_o (cpu_axi_bready),
    .axi_i_arvalid_o(cpu_axi_arvalid),
    .axi_i_araddr_o (cpu_axi_araddr),
    .axi_i_arready_i(soc_axi_arready),
    .axi_i_rvalid_i (soc_axi_rvalid),
    .axi_i_rdata_i  (soc_axi_rdata),
    .axi_i_rresp_i  (soc_axi_rresp),
    .axi_i_rready_o (cpu_axi_rready),

    // AXI Target 接口 (程序下载口 - 透传到顶层)
    .axi_t_awvalid_i(axi_t_awvalid_i), .axi_t_awaddr_i(axi_t_awaddr_i),
    .axi_t_awid_i(axi_t_awid_i),       .axi_t_awlen_i(axi_t_awlen_i),
    .axi_t_awburst_i(axi_t_awburst_i), .axi_t_awready_o(axi_t_awready_o),
    .axi_t_wvalid_i(axi_t_wvalid_i),   .axi_t_wdata_i(axi_t_wdata_i),
    .axi_t_wstrb_i(axi_t_wstrb_i),     .axi_t_wlast_i(axi_t_wlast_i),
    .axi_t_wready_o(axi_t_wready_o),   .axi_t_bvalid_o(axi_t_bvalid_o),
    .axi_t_bresp_o(axi_t_bresp_o),     .axi_t_bid_o(axi_t_bid_o),
    .axi_t_bready_i(axi_t_bready_i),   .axi_t_arvalid_i(axi_t_arvalid_i),
    .axi_t_araddr_i(axi_t_araddr_i),   .axi_t_arid_i(axi_t_arid_i),
    .axi_t_arlen_i(axi_t_arlen_i),     .axi_t_arburst_i(axi_t_arburst_i),
    .axi_t_arready_o(axi_t_arready_o), .axi_t_rvalid_o(axi_t_rvalid_o),
    .axi_t_rdata_o(axi_t_rdata_o),     .axi_t_rresp_o(axi_t_rresp_o),
    .axi_t_rid_o(axi_t_rid_o),         .axi_t_rlast_o(axi_t_rlast_o),
    .axi_t_rready_i(axi_t_rready_i)
);

//-----------------------------------------------------------------
// 2. 实例化 SoC 外设子系统
//-----------------------------------------------------------------
soc u_soc (
    .clk_i(clk_i),
    .rst_i(rst_i),

    // CPU 数据端口对接 (将 AXI-Lite 适配为 AXI4)
    .cpu_d_awvalid_i (cpu_axi_awvalid),
    .cpu_d_awaddr_i  (cpu_axi_awaddr),
    .cpu_d_awid_i    (4'd0),         // ID固定为0
    .cpu_d_awlen_i   (8'd0),         // 长度固定为1 (0表示1次)
    .cpu_d_awburst_i (2'b01),        // 模式固定为INCR
    .cpu_d_awready_o (soc_axi_awready),
    .cpu_d_wvalid_i  (cpu_axi_wvalid),
    .cpu_d_wdata_i   (cpu_axi_wdata),
    .cpu_d_wstrb_i   (cpu_axi_wstrb),
    .cpu_d_wlast_i   (1'b1),         // AXI-Lite 每一拍都是 Last
    .cpu_d_wready_o  (soc_axi_wready),
    .cpu_d_bvalid_o  (soc_axi_bvalid),
    .cpu_d_bresp_o   (soc_axi_bresp),
    .cpu_d_bready_i  (cpu_axi_bready),
    .cpu_d_arvalid_i (cpu_axi_arvalid),
    .cpu_d_araddr_i  (cpu_axi_araddr),
    .cpu_d_arid_i    (4'd0),
    .cpu_d_arlen_i   (8'd0),
    .cpu_d_arburst_i (2'b01),
    .cpu_d_arready_o (soc_axi_arready),
    .cpu_d_rvalid_o  (soc_axi_rvalid),
    .cpu_d_rdata_o   (soc_axi_rdata),
    .cpu_d_rresp_o   (soc_axi_rresp),
    .cpu_d_rready_i  (cpu_axi_rready),
    
    // CPU 指令端口 (CPU已经自带TCM，不需要从外设取指，全部接0)
    .cpu_i_awvalid_i(1'b0), .cpu_i_arvalid_i(1'b0), .cpu_i_wvalid_i(1'b0),
    /* 其余输入端口接0，输出端口悬空即可 */

    // 封死不需要的接口 (第三方访问和外部内存访问)
    .inport_awvalid_i(1'b0), .inport_arvalid_i(1'b0),
    .mem_awready_i(1'b0), .mem_wready_i(1'b0), .mem_arready_i(1'b0),
    .mem_rvalid_i(1'b0), .mem_bvalid_i(1'b0),

    // 物理 IO 对接
    .uart_txd_i(uart_rx_i),
    .uart_rxd_o(uart_tx_o),
    .spi_miso_i(spi_miso_i),
    .spi_mosi_o(spi_mosi_o),
    .spi_clk_o (spi_clk_o),
    .spi_cs_o  (spi_cs_o),
    .gpio_input_i(gpio_in_i),
    .gpio_output_o(gpio_out_o),
    
    // 中断输出连回 CPU
    .intr_o(soc_intr_w)
);

endmodule