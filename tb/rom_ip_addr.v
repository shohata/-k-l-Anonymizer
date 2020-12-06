`timescale 1 ps / 1 ps

module rom_ip_addr (
  input  wire        clk,
  output reg  [31:0] data,
  input  wire [11:0] address
);

  reg[31:0] rom [0:4095];

  initial $readmemh("/home/shohata/proj/k-l-anonymizer/tb/westlab_0111_srcip_4096.dat", rom);

  always @(posedge clk) data <= rom[address];

endmodule
