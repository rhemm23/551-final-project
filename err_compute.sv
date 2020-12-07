module err_compute(error, err_vld, IR_vld, clk, rst_n, IR_R0,IR_R1,IR_R2,IR_R3,
                    IR_L0,IR_L1,IR_L2,IR_L3);
					
	input [11:0] IR_R0,IR_R1,IR_R2,IR_R3;
	input [11:0] IR_L0,IR_L1,IR_L2,IR_L3;
	input IR_vld, clk, rst_n;
	output reg signed [15:0] error;
	output logic err_vld;
	
	logic en_accum, clr_accum;
	wire [2:0] sel;	
	
	err_compute_SM sm(.sel(sel), .err_vld(err_vld), .IR_vld(IR_vld), .clr_accum(clr_accum), .en_accum(en_accum), .clk(clk), .rst_n(rst_n));			
	err_compute_DP datapath(.clk(clk),.en_accum(en_accum),.clr_accum(clr_accum),.sub(sel[0]),.sel(sel),.IR_R0(IR_R0),.IR_R1(IR_R1),.IR_R2(IR_R2),.IR_R3(IR_R3),
                    .IR_L0(IR_L0),.IR_L1(IR_L1),.IR_L2(IR_L2),.IR_L3(IR_L3),.error(error));
	
endmodule