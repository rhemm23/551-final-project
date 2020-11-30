module err_compute_SM(clk, rst_n, IR_vld, sel, clr_accum, en_accum, err_vld);

  input clk, rst_n, IR_vld;
  
  output logic en_accum, err_vld;
  output logic [2:0] sel;
  output clr_accum;
  
  reg [3:0] sel_cnt;
  
  logic init;

  typedef enum reg [1:0] { IDLE, SEL } state_t;
  state_t state, next_state;
  
  // State flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
      
  // Select counter
  always_ff @(posedge clk)
    if (init)
      sel_cnt <= 4'h0;
    else if (en_accum)
      sel_cnt <= sel_cnt + 1;

  // SM logic
  always_comb begin
    // Clear SM outputs
    sel = 3'b000;
    en_accum = 0;
    err_vld = 0;
    init = 0;
    
    // State transitions
    case (state)
      ///// Select case, read the eight IR values /////
      SEL : if (sel_cnt == 4'h8) begin
        err_vld = 1;
        next_state = IDLE;
      end else begin
        en_accum = 1;
        sel = sel_cnt;
        next_state = SEL;
      end
      ///// default case = IDLE /////
      default : if (IR_vld) begin
        init = 1;
        next_state = SEL;
      end else begin
        next_state = IDLE;
      end
    endcase
  end
  
  // Clear accumulator when initializing
  assign clr_accum = init;
  
endmodule

