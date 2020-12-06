`timescale 1 ps / 1 ps

module rom_url (
  input  wire         clk,
  output reg  [511:0] data,
  input  wire  [11:0] address
);

  reg[511:0] rom [0:4095];

  initial $readmemh("/home/shohata/proj/k-l-anonymizer/tb/westlab_0111_url_2_4096.dat", rom);

  always @(posedge clk) data <= rom[address];

endmodule
