module IR_intf(clk, rst_n, IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3, IR_en, IR_vld, line_present, SS_n, SCLK, MOSI, MISO);

  localparam LINE_THRES = 12'h040;

  parameter FAST_SIM = 0;
  
  input MISO, clk, rst_n;
  
  output reg [11:0] IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3;
  output logic IR_en, IR_vld, line_present;
  
  output SS_n, SCLK, MOSI;
  
  reg [17:0] tmr;
  reg [11:0] IR_max;
  
  logic rst_tmr, strt_cnv, clr, EN_R0, EN_R1, EN_R2, EN_R3, EN_L0, EN_L1, EN_L2, EN_L3, inc_chnnl, clr_chnnl;
  logic [2:0] chnnl;
  
  wire nxt_round, settled, cnv_cmplt;
  wire [11:0] res;
  
  typedef enum reg [2:0] { IDLE, WAIT_TMR, IR_SETTLE, START_CNV, WAIT_CNV } state_t;
  state_t state, next_state;
  
  A2D_intf a2d(.clk(clk), .rst_n(rst_n), .chnnl(chnnl), .strt_cnv(strt_cnv), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .cnv_cmplt(cnv_cmplt), .res(res));
  
  // Output flops
  always_ff @(posedge clk)
    if (EN_R0)
      IR_R0 <= res;
      
  always_ff @(posedge clk)
    if (EN_R1)
      IR_R1 <= res;
      
  always_ff @(posedge clk)
    if (EN_R2)
      IR_R2 <= res;
      
  always_ff @(posedge clk)
    if (EN_R3)
      IR_R3 <= res;
      
  always_ff @(posedge clk)
    if (EN_L0)
      IR_L0 <= res;
  
  always_ff @(posedge clk)
    if (EN_L1)
      IR_L1 <= res;
  
  always_ff @(posedge clk)
    if (EN_L2)
      IR_L2 <= res;
  
  always_ff @(posedge clk)
    if (EN_L3)
      IR_L3 <= res;
  
  always_ff @(posedge clk)
    if (clr_chnnl)
      chnnl <= 3'b000;
    else if (inc_chnnl)
      chnnl <= chnnl + 1;
  
  // Timer flop
  always_ff @(posedge clk)
    if (rst_tmr)
      tmr <= 18'h00000;
    else
      tmr <= tmr + 1;
  
  // SM flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  
  // Line present flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      line_present <= 1'b0;
    else if (IR_vld) begin
      if (IR_max > LINE_THRES)
        line_present <= 1'b1;
      else
        line_present <= 1'b0;
    end
  
  // IR max flop
  always_ff @(posedge clk)
    if (clr)
      IR_max <= 12'h000;
    else if (cnv_cmplt && res > IR_max)
      IR_max <= res;
  
  // SM logic
  always_comb begin
    // Clear logic
    clr = 0;
    IR_en = 0;
    IR_vld = 0;
    rst_tmr = 0;
    strt_cnv = 0;
    inc_chnnl = 0;
    clr_chnnl = 0;
    
    // Clear enables
    EN_R0 = 0;
    EN_R1 = 0;
    EN_R2 = 0;
    EN_R3 = 0;
    EN_L0 = 0;
    EN_L1 = 0;
    EN_L2 = 0;
    EN_L3 = 0;
  
    case(state)
      // IDLE : resets timer and goes to waiting state
      default : begin
        clr = 1;
        rst_tmr = 1;
        next_state = WAIT_TMR;
      end
      // Wait for timer to fill before starting
      WAIT_TMR : if (nxt_round) begin
        clr = 1;
        rst_tmr = 1;
        next_state = IR_SETTLE;
      end else begin
        clr = 1;
        next_state = WAIT_TMR;
      end
      // Wait for IR sensor values to settle
      IR_SETTLE : if (settled) begin
        IR_en = 1;
        clr_chnnl = 1;
        next_state = START_CNV;
      end else begin
        IR_en = 1;
        next_state = IR_SETTLE;
      end
      // Starts conversion of specific channel
      START_CNV : begin
        IR_en = 1;
        strt_cnv = 1;
        next_state = WAIT_CNV;
      end
      // Waits for the conversion to finish
      WAIT_CNV : if (cnv_cmplt) begin
        // Store value in appropriate register
        case (chnnl)
          3'b001 : EN_R1 = 1;
          3'b010 : EN_R2 = 1;
          3'b011 : EN_R3 = 1;
          3'b100 : EN_L0 = 1;
          3'b101 : EN_L1 = 1;
          3'b110 : EN_L2 = 1;
          3'b111 : EN_L3 = 1;
          default : EN_R0 = 1;
        endcase
        // Increment channel, go to next appropriate state
        inc_chnnl = 1;
        if (chnnl == 3'b111) begin
          IR_vld = 1;
          next_state = IDLE;
        end else begin
          IR_en = 1;
          next_state = START_CNV;
        end
      end else begin
        IR_en = 1;
        next_state = WAIT_CNV;
      end
    endcase
  end
  
  // Generate based on whether module is FAST_SIM or not
  generate 
    if (FAST_SIM) begin
      assign nxt_round = &tmr[13:0];
      assign settled = &tmr[10:0];
    end else begin
      assign nxt_round = &tmr;
      assign settled = &tmr[11:0];
    end 
  endgenerate
endmodule
