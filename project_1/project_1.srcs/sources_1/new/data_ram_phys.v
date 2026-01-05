module data_ram_phys (
    input clk_i,
    input [13:0] addr_i,
    input [31:0] data_i,
    input [3:0]  wr_i,
    output [31:0] data_o
);
    reg [31:0] ram [16383:0];
    reg [31:0] read_q;

    always @(posedge clk_i) begin
        if (wr_i[0]) ram[addr_i][7:0]   <= data_i[7:0];
        if (wr_i[1]) ram[addr_i][15:8]  <= data_i[15:8];
        if (wr_i[2]) ram[addr_i][23:16] <= data_i[23:16];
        if (wr_i[3]) ram[addr_i][31:24] <= data_i[31:24];
        read_q <= ram[addr_i];
    end
    assign data_o = read_q;
endmodule