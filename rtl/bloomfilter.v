`timescale 1 ps / 1 ps

module bloomfilter #(
  parameter DATA_WIDTH = 32
) (
  input  wire [DATA_WIDTH-1:0] data_in,
  input  wire           [31:0] bf_array_in,
  output reg            [31:0] bf_array_out,
  output reg                   match
);

  wire [31:0] hash_val1, hash_val2;

  // Two hash functions
  crc #(
    .DATA_WIDTH   (DATA_WIDTH),
    .CRC_WIDTH    (32),
    .POLYNOMIAL   (32'b00000100_11000001_00011101_10110111),
    .SEED_VAL     (32'h0),
    .OUTPUT_EXOR  (32'h0)
  )
  crc_1_inst (
    .datain (data_in),
    .crcout (hash_val1)
  );

  crc #(
    .DATA_WIDTH   (DATA_WIDTH),
    .CRC_WIDTH    (32),
    .POLYNOMIAL   (32'b00000100_11000001_00011101_10110111),
    .SEED_VAL     (32'hFFFFFFFF),
    .OUTPUT_EXOR  (32'h0)
  )
  crc_2_inst (
    .datain (data_in),
    .crcout (hash_val2)
  );

  always @(*) begin
    // is data_in included in bloomfilter set?
    if(bf_array_in[hash_val1[4:0]] & bf_array_in[hash_val2[4:0]])
      match = 1'b1;
    else
      match = 1'b0;
    // update bloomfilter array
    bf_array_out = bf_array_in;
    bf_array_out[hash_val1[4:0]] = 1'b1;
    bf_array_out[hash_val2[4:0]] = 1'b1;
  end

endmodule
