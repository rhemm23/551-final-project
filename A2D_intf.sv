module A2D_intf(clk, rst_n, chnnl, strt_cnv, SS_n, SCLK, MOSI, MISO, cnv_cmplt, res);

  input clk, rst_n, MISO, strt_cnv;
  input [2:0] chnnl;
  
  wire done;
  wire [15:0] cmd;
  wire [15:0] rd_data;
  
  output SS_n, SCLK, MOSI;
  output reg cnv_cmplt;
  output [11:0] res;
  
  typedef enum reg [2:0] { IDLE, FIRST_CMD, FIRST_CMD_STALL, SECOND_CMD, SECOND_CMD_STALL } state_t;
  state_t state, next_state;

  logic wrt, set_cnv_cmplt, init;

  SPI_mstr16 iSPI(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data));

  // State flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  
  // Conversion complete output
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      cnv_cmplt <= 1'b0;
    else if (set_cnv_cmplt)
      cnv_cmplt <= 1'b1;
    else if (init)
      cnv_cmplt <= 1'b0;

  // SM logic
  always_comb begin
    // Clear outputs
    wrt = 0;
    init = 0;
    set_cnv_cmplt = 0;
 
    case (state)
      // Send the command to SPI
      FIRST_CMD : if (done) begin
        next_state = FIRST_CMD_STALL;
      end else begin
        next_state = FIRST_CMD;
      end
      // Added for extra clk cycle between commands
      FIRST_CMD_STALL : begin
        wrt = 1;
        next_state = SECOND_CMD;
      end
      // Second command, receive response
      SECOND_CMD : if (done) begin
        next_state = SECOND_CMD_STALL;
      end else begin
        next_state = SECOND_CMD;
      end
      // Again added for extra clk cycle
      SECOND_CMD_STALL : begin
        set_cnv_cmplt = 1;
        next_state = IDLE;
      end
      ///// default case = IDLE /////
      default : if (strt_cnv) begin
        wrt = 1;
        init = 1;
        next_state = FIRST_CMD;
      end else begin
        next_state = IDLE;
      end
    endcase
  end

  // 1's complement
  assign res = ~rd_data;

  // SPI command
  assign cmd = { 2'b00, chnnl, 11'h000 };

endmodule
