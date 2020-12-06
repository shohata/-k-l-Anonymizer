`timescale 1 ps / 1 ps

/*
 * Simple Dual-Port Block RAM with One Clock
 */
module ram #(
  parameter ADDR_WIDTH = 12,
  parameter DATA_WIDTH = 32,
  parameter WORDS = 4096
) (
  input  wire                  clk,
  input  wire                  we,
  input  wire [ADDR_WIDTH-1:0] r_addr,
  output reg  [DATA_WIDTH-1:0] r_data,
  input  wire [ADDR_WIDTH-1:0] w_addr,
  input  wire [DATA_WIDTH-1:0] w_data
);

  (* ram_style = "BLOCK" *) reg [DATA_WIDTH-1:0] ram [WORDS-1:0];

  integer i;
  initial begin
    for (i=0; i<WORDS; i=i+1) begin
      ram[i] = 0;
    end
  end

  always @(posedge clk) begin
    if (we) ram[w_addr] <= w_data;
  end

  always @(posedge clk) begin
    r_data <= ram[r_addr];
  end

endmodule
