`timescale 1 ps / 1 ps

module inserter (
  input  wire         clk,
  output wire  [31:0] ip_addr_data,
  output wire [511:0] url_data,
  input  wire  [11:0] address
);

  rom_ip_addr
  rom_ip_addr_inst (
    .clk      (clk),
    .data     (ip_addr_data),
    .address  (address)
  );

  rom_url
  rom_url_inst (
    .clk      (clk),
    .data     (url_data),
    .address  (address)
  );

endmodule
