`timescale 1 ps / 1 ps

module k_l_anonymizer #(
  parameter       ADDR_WIDTH = 12,      // Address width
  parameter       RAM_ADDR_WIDTH = 14,  // RAM address width
  parameter       Q_ID_WIDTH = 32,      // Quasi-identifier width
  parameter       Q_ID_MASK_WIDTH = 6,  // Quasi-identifier mask width (=1+log2 Q_ID_WIDTH)
  parameter       S_ATTR_WIDTH = 32     // Sensitive attribute width
) (
  input  wire clk,
  input  wire rst,

  // Window Size
  input wire [ADDR_WIDTH:0] window_size,

  // Privacy Model
  input wire [3:0] k_anonymity, // k-anonymity
  input wire [3:0] l_diversity, // l-diversity

  // Input a tuple consisting of quasi-identifier and sensitive attribute if write_enable is true
  input  wire   [Q_ID_WIDTH-1:0] q_id_in,       // quasi-identifier
  input  wire [S_ATTR_WIDTH-1:0] s_attr_in,     // sensitive attribute
  input  wire                    write_enable,  // write enable

  // Output a tuple at the address of read_address
  output wire      [Q_ID_WIDTH-1:0] q_id_out,       // quasi-identifier
  output wire [Q_ID_MASK_WIDTH-1:0] q_id_mask_out,  // quasi-identifier mask
  output wire    [S_ATTR_WIDTH-1:0] s_attr_out,     // sensitive attribute
  input  wire      [ADDR_WIDTH-1:0] read_address,   // read address
  output wire                       all_finished    // has all finished? (are write and read ready?)
);

  localparam [1:0] IDLE = 0, INIT = 1, WRITE_RAM = 2, UPDATE_BUF = 3;
  localparam [Q_ID_MASK_WIDTH-1:0] Q_ID_MASK_NULL = 0, Q_ID_MASK_ALL = Q_ID_WIDTH;
  localparam WINDOW_SIZE = 1 << ADDR_WIDTH , RAM_WORDS = 1 << RAM_ADDR_WIDTH;

  reg                  [1:0] state;
  reg                        finished;
  reg       [ADDR_WIDTH-1:0] write_address;
  reg         [ADDR_WIDTH:0] window_size_reg;
  reg                  [3:0] k_anonymity_reg;
  reg                  [3:0] l_diversity_reg;

  reg       [ADDR_WIDTH-1:0] buf_r_addr;
  wire      [Q_ID_WIDTH-1:0] buf_r_q_id;
  wire [Q_ID_MASK_WIDTH-1:0] buf_r_q_id_mask;
  wire    [S_ATTR_WIDTH-1:0] buf_r_s_attr;
  wire                       buf_r_finished;

  reg       [ADDR_WIDTH-1:0] buf_w_addr, _buf_w_addr;
  reg       [Q_ID_WIDTH-1:0] buf_w_q_id;
  reg  [Q_ID_MASK_WIDTH-1:0] buf_w_q_id_mask;
  wire [Q_ID_MASK_WIDTH-1:0] buf_w_q_id_mask_next;
  reg     [S_ATTR_WIDTH-1:0] buf_w_s_attr;
  reg                        buf_w_finished;
  wire                       buf_w_finished_next;

  wire  [RAM_ADDR_WIDTH-1:0] ram_r_addr;
  wire      [Q_ID_WIDTH-1:0] ram_r_q_id;
  wire [Q_ID_MASK_WIDTH-1:0] ram_r_q_id_mask;
  wire                 [3:0] r_k_anonymity;
  wire                 [3:0] r_l_diversity;
  wire                       r_full;

  reg   [RAM_ADDR_WIDTH-1:0] ram_w_addr;

  wire                [31:0] bf_array_out;
  wire                [31:0] bf_array_in;
  wire                       bf_match;

  wire                [15:0] buf_r_q_id_crc;

  /*
   * State Machine
   */
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end
    else begin
      case (state)
        IDLE: begin
          if (write_enable && write_address == window_size_reg - 1)
            state <= INIT;
        end
        INIT: begin
          if (buf_r_addr == 1)
            state <= WRITE_RAM;
        end
        WRITE_RAM: begin
          if (buf_w_addr == window_size_reg - 1)
            state <= UPDATE_BUF;
        end
        UPDATE_BUF: begin
          if (buf_w_addr == window_size_reg - 1) begin
            if (finished)
              state <= IDLE;
            else
              state <= WRITE_RAM;
          end
        end
      endcase
    end
  end

  always @(posedge clk) begin
    if (state == IDLE) begin
      window_size_reg <= window_size;
      k_anonymity_reg <= k_anonymity;
      l_diversity_reg <= l_diversity;
    end
  end

  assign all_finished = (state == IDLE && write_address == 0);

  /*
   * Buffer
   */
  ram #(
    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( Q_ID_WIDTH + Q_ID_MASK_WIDTH + S_ATTR_WIDTH + 1 ),
    .WORDS      ( WINDOW_SIZE )
  )
  buffer_inst (
    .clk    ( clk ),
    .we     ( (state == IDLE) ? write_enable : (state == UPDATE_BUF) ? ~buf_w_finished : 1'b0 ),
    .r_addr ( (state == IDLE) ? read_address : buf_r_addr ),
    .r_data ( {buf_r_q_id, buf_r_q_id_mask, buf_r_s_attr, buf_r_finished} ),
    .w_addr ( (state == IDLE)? write_address : buf_w_addr ),
    .w_data (
      (state == IDLE)
        ? {q_id_in, Q_ID_MASK_NULL, s_attr_in, 1'b0}
        : {
            buf_w_q_id & ({Q_ID_WIDTH{1'b1}} << buf_w_q_id_mask_next),
            buf_w_q_id_mask_next,
            buf_w_s_attr,
            buf_w_finished_next
          }
    )
  );

  assign q_id_out = buf_r_q_id;
  assign q_id_mask_out = buf_r_q_id_mask;
  assign s_attr_out = buf_r_s_attr;

  // if not finished, quasi-identifier mask is incremented.
  assign buf_w_q_id_mask_next = (buf_w_finished_next) ? ram_r_q_id_mask : ram_r_q_id_mask + 1;

  // if k-anonymity and l-diversity have been satisfied or quasi-id has been masked all, finished.
  assign buf_w_finished_next
    = ((r_k_anonymity >= k_anonymity_reg && r_l_diversity >= l_diversity_reg)
      || (ram_r_q_id_mask == Q_ID_MASK_ALL) || buf_w_finished);

  always @(posedge clk) begin
    if (rst)
      write_address <= 0;
    else begin
      if (state == IDLE) begin
        if (write_enable) write_address <= write_address + 1;
      end else
        write_address <= 0;
    end
  end

  always @(posedge clk) begin
    if (state == IDLE)
      buf_r_addr <= 0;
    else begin
      if (buf_r_addr == window_size_reg - 1)
        buf_r_addr <= 0;
      else
        buf_r_addr <= buf_r_addr + 1;
    end
    buf_w_addr <= _buf_w_addr;
    _buf_w_addr <= buf_r_addr;
    buf_w_q_id <= buf_r_q_id;
    buf_w_q_id_mask <= buf_r_q_id_mask;
    buf_w_s_attr <= buf_r_s_attr;
    buf_w_finished <= buf_r_finished;
    if (state == UPDATE_BUF) begin
      if (buf_w_addr == 0)
        finished <= buf_w_finished;
      else
        finished <= finished & buf_w_finished;
    end
  end

  /*
   * RAM
   *
   * RAM module stores quasi-identifieres and states for ram-based anonymization.
   * The stored values are quasi-identifier, quasi-identifier mask, k-anonymity,
   * l-diversity, a BloomFilter array, and a state of full or empty.
   *
   * The access address is CRC hash value caluclated from quasi-identifier and its mask.
   * If hash collision has occured by the hash value, the quasi-identifier is masked all.
   *
   * The BloomFilter array is used for counting l-diversity.
   * If the BF array has not matched hash value of sensitive attribute,
   * the sensitive attribute is new and l-diversity count is incremented.
   */
  ram #(
    .ADDR_WIDTH ( RAM_ADDR_WIDTH ),
    .DATA_WIDTH ( Q_ID_WIDTH + Q_ID_MASK_WIDTH + 4 + 4 + 32 + 1 ),
    .WORDS      ( RAM_WORDS )
  )
  ram_inst (
    .clk    ( clk ),
    .we     ( (state == WRITE_RAM) ? ~buf_w_finished : 1'b1 ),
    .r_addr ( ram_r_addr ),
    .r_data ( {ram_r_q_id, ram_r_q_id_mask, r_k_anonymity, r_l_diversity, bf_array_in, r_full} ),
    .w_addr ( ram_w_addr ),
    .w_data (
      (state == WRITE_RAM)
        ? {
            buf_w_q_id,
            (!r_full) ? buf_w_q_id_mask : ({ram_r_q_id, ram_r_q_id_mask} != {buf_w_q_id, buf_w_q_id_mask}) ? Q_ID_MASK_ALL : ram_r_q_id_mask,
            (!r_full) ? 4'b1 : r_k_anonymity + 4'b1,
            (!r_full) ? 4'b1 : (!bf_match) ? r_l_diversity + 4'b1 : r_l_diversity,
            bf_array_out, 1'b1
          }
        : {ram_r_q_id, ram_r_q_id_mask, r_k_anonymity, r_l_diversity, bf_array_in, 1'b0} // clear
    )
  );

  assign ram_r_addr = buf_r_q_id_crc[RAM_ADDR_WIDTH-1:0];

  always @(posedge clk) begin
    ram_w_addr <= ram_r_addr;
  end

  /*
   * BloomFilter
   */
  bloomfilter #(
    .DATA_WIDTH   ( S_ATTR_WIDTH )
  )
  bloomfilter_inst (
    .data_in      ( buf_r_s_attr ),
    .bf_array_in  ( bf_array_in ),
    .bf_array_out ( bf_array_out ),
    .match        ( bf_match )
  );

  /*
   * CRC Function
   */
  crc #(
    .DATA_WIDTH   ( Q_ID_WIDTH + Q_ID_MASK_WIDTH ),
    .CRC_WIDTH    ( 16 ),
    .POLYNOMIAL   ( 16'b1000_0000_0000_0101 ),
    .SEED_VAL     ( 16'h0 ),
    .OUTPUT_EXOR  ( 16'h0 )
  )
  crc16_32_buf_inst (
    .datain ( {buf_r_q_id, buf_r_q_id_mask} ),
    .crcout ( buf_r_q_id_crc )
  );

endmodule
