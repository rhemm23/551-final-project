module SPI_mstr16(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, cmd, done, rd_data);

  input clk, rst_n, MISO, wrt;
  input [15:0] cmd;
  
  output SCLK, MOSI;
  output reg SS_n, done;
  output [15:0] rd_data;
  
  reg MISO_smpl;
  reg [5:0] shft_cnt;
  reg [5:0] sclk_div;
  reg [15:0] shft_reg;
  
  typedef enum reg [1:0] { IDLE, FRONT, SHIFTING, BACK } state_t;
  state_t state, next_state;
  
  logic rst_cnt, smpl, shft, set_done, init;
  wire sclk_fall, sclk_rise;
  
  // Done flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      done <= 1'b0;
    else if (set_done)
      done <= 1'b1;
    else if (init)
      done <= 1'b0;
  
  // SS flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      SS_n <= 1'b1;
    else if (set_done)
      SS_n <= 1'b1;
    else if (init)
      SS_n <= 1'b0;
  
  // Sample counter for SM
  always_ff @(posedge clk)
    if (init)
      shft_cnt <= 1'b0;
    else if (shft)
      shft_cnt <= shft_cnt + 1;
  
  // MISO sample register
  always_ff @(posedge clk)
    if (smpl)
      MISO_smpl <= MISO;
  
  // Main shift register
  always_ff @(posedge clk)
    if (wrt)
      shft_reg <= cmd;
    else if (shft)
      shft_reg <= { shft_reg[14:0], MISO_smpl };
  
  // SCLK div
  always_ff @(posedge clk)
    if (rst_cnt)
      sclk_div <= 6'b101111;
    else
      sclk_div <= sclk_div + 1;
  
  // SM flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  
  // SM logic
  always_comb begin
    // Clear SM outputs
    set_done = 0;
    rst_cnt = 0;
    init = 0;
    smpl = 0;
    shft = 0;

    case (state)
      ///// First sclk high before we start shifting /////
      FRONT : if (sclk_fall) begin
        next_state = SHIFTING;
      end else begin
        next_state = FRONT;
      end
      ///// Shifting in and out bits of the current packet /////
      SHIFTING : if (shft_cnt == 6'h0F) begin
        next_state = BACK;
      end else begin
        shft = sclk_fall;
        smpl = sclk_rise;
        next_state = SHIFTING;
      end
      ///// Last sclk period before we are done with the current packet /////
      BACK : if (sclk_fall) begin
        shft = 1;
        rst_cnt = 1;
        set_done = 1;
        next_state = IDLE;
      end else begin
        smpl = sclk_rise;
        next_state = BACK;
      end
      ///// default case = IDLE /////
      default : if (wrt) begin
        init = 1;
        next_state = FRONT;
      end else begin
        rst_cnt = 1;
        next_state = IDLE;
      end
    endcase
  end
  
  // Watch for SCLK changes
  assign sclk_fall = &sclk_div;
  assign sclk_rise = ~sclk_div[5] && &sclk_div[4:0];
  
  // MSB is SCLK
  assign SCLK = sclk_div[5];
  
  // Data is from shift register
  assign rd_data = shft_reg;
  assign MOSI = shft_reg[15];

endmodule
