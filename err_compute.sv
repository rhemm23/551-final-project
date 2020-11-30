module err_compute(clk, rst_n, IR_vld, IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3, error, err_vld);

  input clk, rst_n, IR_vld;
  input [11:0] IR_R0,IR_R1,IR_R2,IR_R3; // Right IR readings from inside out
  input [11:0] IR_L0,IR_L1,IR_L2,IR_L3; // Left IR reading from inside out

  output [15:0] error;
  output err_vld;
  
  wire en_accum, clr_accum;
  wire [2:0] sel;

  // Datapath
  err_compute_DP iDP(.clk(clk),.en_accum(en_accum),.clr_accum(clr_accum),.sub(sel[0]),
                   .sel(sel),.IR_R0(IR_R0),.IR_R1(IR_R1),.IR_R2(IR_R2),.IR_R3(IR_R3),
                   .IR_L0(IR_L0),.IR_L1(IR_L1),.IR_L2(IR_L2),.IR_L3(IR_L3),.error(error));
  
  // State machine
  err_compute_SM iSM(.clk(clk), .rst_n(rst_n), .IR_vld(IR_vld),
    .sel(sel), .clr_accum(clr_accum), .en_accum(en_accum), .err_vld(err_vld));

endmodule
