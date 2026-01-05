module instr_rom_phys (
    input clk_i,
    input [13:0] addr_i,
    output [31:0] data_o
);
    reg [31:0] rom [16383:0];
    reg [31:0] read_q;

    always @(posedge clk_i) begin
        read_q <= rom[addr_i];
    end
    assign data_o = read_q;
endmodule