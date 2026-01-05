`timescale 1ns / 1ps

/**
 * RISC-V SoC 集成测试平台
 * 适用对象：riscv_soc_top.v (包含内核 + 外设)
 */
module tb_top();
    
    //---------------------------------------------------------
    // 1. 信号定义
    //---------------------------------------------------------
    logic         clk;
    logic         rst_sys;
    logic         rst_cpu;

    // 外设引脚
    logic         uart_tx;
    logic         uart_rx;
    logic [31:0]  gpio_in;
    logic [31:0]  gpio_out;
    
    logic         spi_miso;
    logic         spi_mosi;
    logic         spi_clk;
    logic         spi_cs;

    //---------------------------------------------------------
    // 2. 时钟产生: 50MHz (周期 20ns)
    //---------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    //---------------------------------------------------------
    // 3. 实例化新的顶层设计 (DUT)
    //---------------------------------------------------------
    riscv_soc_top #(
        .BOOT_VECTOR(32'h00002000), 
        .TCM_MEM_BASE(32'h00000000)
    ) u_dut (
        .clk_i           (clk),
        .rst_i           (rst_sys),   
        .rst_cpu_i       (rst_cpu),   
        
        // 外部加载接口 (仿真中暂时置零)
        .axi_t_awvalid_i (1'b0), .axi_t_awaddr_i(32'b0), .axi_t_awid_i(4'b0),
        .axi_t_awlen_i(8'b0),    .axi_t_awburst_i(2'b0), .axi_t_wvalid_i(1'b0),
        .axi_t_wdata_i(32'b0),   .axi_t_wstrb_i(4'b0),   .axi_t_wlast_i(1'b0),
        .axi_t_bready_i(1'b1),   .axi_t_arvalid_i(1'b0), .axi_t_araddr_i(32'b0),
        .axi_t_arid_i(4'b0),     .axi_t_arlen_i(8'b0),    .axi_t_arburst_i(2'b0),
        .axi_t_rready_i(1'b1),

        // 物理外设接口
        .uart_rx_i       (uart_rx),
        .uart_tx_o       (uart_tx),
        .spi_miso_i      (1'b0),
        .spi_mosi_o      (spi_mosi),
        .spi_clk_o       (spi_clk),
        .spi_cs_o        (spi_cs),
        .gpio_in_i       (gpio_in),
        .gpio_out_o      (gpio_out)
    );

    //---------------------------------------------------------
    // 4. 仿真流程
    //---------------------------------------------------------
    initial begin
        // --- 核心修改：更新内存加载路径 ---
        // 路径：顶层(u_dut) -> 内核封装(u_riscv) -> TCM控制器(u_tcm) -> 物理内存(u_pmem) -> 数组(ram_q)
        $readmemh("C:/Users/28415/Downloads/project_1/project_1/project_1.srcs/sources_1/imports/riscv_project1/test.hex", u_dut.u_riscv.u_tcm.u_ram.ram);
        
        $display("[%0t] Program loaded to TCM", $time);

        // 初始化状态
        rst_sys = 1;
        rst_cpu = 1;
        uart_rx = 1; // UART 空闲位为高
        gpio_in = 32'hA5A5A5A5; // 模拟拨码开关输入

        $display("----------------------------------------------");
        $display("[%0t] Simulation Started with Peripherals", $time);
        
        // Step 1: 释放系统复位 (SoC总线和TCM准备就绪)
        #100;
        rst_sys = 0;
        $display("[%0t] System Bus Ready", $time);

        // Step 2: 释放 CPU 复位 (开始从 0x2000 执行)
        #200;
        rst_cpu = 0;
        $display("[%0t] CPU Booting...", $time);

        // Step 3: 监控运行情况
        repeat(1000) begin
            @(posedge clk);
            if (!rst_cpu) begin
                // 监控 PC 值的路径也需要更新
                $display("[%0t] PC: 0x%h | GPIO_OUT: 0x%h | UART_TX: %b", 
                         $time, u_dut.u_riscv.ifetch_pc_w, gpio_out, uart_tx);
            end
            
            // 如果检测到 GPIO 输出变化，打印出来
            if (gpio_out !== 32'b0) begin
                $display("[%0t] Detected Peripheral Activity! GPIO = 0x%h", $time, gpio_out);
            end
        end

        $display("[%0t] Simulation Finished.", $time);
        $finish;
    end

endmodule