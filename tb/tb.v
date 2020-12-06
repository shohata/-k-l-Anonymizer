`timescale 1 ps / 1 ps

module tb ();

  localparam ADDR_WIDTH = 8;
  localparam [ADDR_WIDTH:0] WINDOW_SIZE = 256;

  reg                    clk;
  reg                    rst;
  reg             [11:0] address;
  wire            [31:0] q_id_in;       // quasi-identifier
  wire           [511:0] s_attr_in;     // sensitive attribute
  reg                    write_enable;  // write enable
  wire            [31:0] q_id_out;      // quasi-identifier
  wire             [5:0] q_id_mask_out; // quasi-identifier mask
  wire           [511:0] s_attr_out;    // sensitive attribute
  reg   [ADDR_WIDTH-1:0] read_address;  // read address
  wire                   all_finished;  // has all finished?

  inserter
  inserter_inst (
    .clk          (clk),
    .ip_addr_data (q_id_in),
    .url_data     (s_attr_in),
    .address      (address)
  );

  k_l_anonymizer #(
    .ADDR_WIDTH       (ADDR_WIDTH),   // Address width
    .RAM_ADDR_WIDTH   (14),           // RAM address width
    .Q_ID_WIDTH       (32),           // Quasi-identifier width
    .Q_ID_MASK_WIDTH  (6),            // Quasi-identifier mask width (=1+log2 Q_ID_WIDTH)
    .S_ATTR_WIDTH     (512)           // Sensitive attribute width
  )
  k_l_anonymizer_inst (
    .clk  (clk) ,
    .rst  (rst),

    .window_size  (WINDOW_SIZE),
    .k_anonymity  (3),
    .l_diversity  (2),

    // Input a tuple consisting of quasi-identifier and sensitive attribute if write_enable is true
    .q_id_in      (q_id_in),      // quasi-identifier
    .s_attr_in    (s_attr_in),    // sensitive attribute
    .write_enable (write_enable), // write enable

    // Output a tuple at the address of read_address
    .q_id_out       (q_id_out),       // quasi-identifier
    .q_id_mask_out  (q_id_mask_out),  // quasi-identifier mask
    .s_attr_out     (s_attr_out),     // sensitive attribute
    .read_address   (read_address),   // read address
    .all_finished   (all_finished)    // has all finished?
  );

  always #5 clk <= ~clk;

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, k_l_anonymizer_inst);
    $dumplimit(10000000);
    clk = 1;
    rst = 1;
    address = 0;
    write_enable = 0;
    read_address = 0;
    repeat (5) @(posedge clk);
    rst <= 0;
    repeat (5) @(posedge clk);
    repeat (WINDOW_SIZE) @(posedge clk) begin
      $display("%h, %h", address, q_id_in);
      address <= address + 1;
      write_enable <= 1;
    end
    @(posedge clk);
    write_enable <= 0;
    @(posedge clk);
    wait(all_finished);
    repeat (WINDOW_SIZE) @(posedge clk) begin
      $display("%h, %h, %d", read_address, q_id_out, q_id_mask_out);
      read_address <= read_address + 1;
    end
    $finish;
  end

endmodule
