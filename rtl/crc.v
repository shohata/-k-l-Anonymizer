`timescale 1 ps / 1 ps

module crc # (
  parameter                 DATA_WIDTH = 8,         // データ幅
  parameter                 CRC_WIDTH = 16,         // CRCデータ幅
  parameter [CRC_WIDTH-1:0] POLYNOMIAL = 16'h1021,  // 生成多項式
  parameter [CRC_WIDTH-1:0] SEED_VAL = 16'h0,       // シード値
  parameter                 OUTPUT_EXOR = 16'h0     // 出力反転
) (
  input [DATA_WIDTH-1:0] datain,                    // 入力データ
  output [CRC_WIDTH-1:0] crcout                     // CRC演算結果出力
);

  assign crcout = crc_calc_l(SEED_VAL, datain) ^ OUTPUT_EXOR;

  /* CRC演算関数
   */
  function [CRC_WIDTH-1:0] crc_calc;
    input [CRC_WIDTH-1:0] in_crc;
    input in_data;
    integer i;
    begin
      for (i = 0; i < CRC_WIDTH; i = i + 1) begin
        crc_calc[i] = 1'b0;
        if (i != 0)
          crc_calc[i] = in_crc[i-1];
        if (POLYNOMIAL[i])
          crc_calc[i] = crc_calc[i] ^ in_crc[CRC_WIDTH-1] ^ in_data;
      end
    end
  endfunction

  /* CRC演算ループ関数
   */
  function [CRC_WIDTH-1:0] crc_calc_l;
    input [CRC_WIDTH-1:0] in_crc;
    input [DATA_WIDTH-1:0] in_data;
    integer i;
    begin
      crc_calc_l = in_crc;
      for (i = 0; i < DATA_WIDTH; i = i + 1) begin
        crc_calc_l = crc_calc(crc_calc_l, in_data[(DATA_WIDTH-1)-i]);
      end
    end
  endfunction

endmodule
