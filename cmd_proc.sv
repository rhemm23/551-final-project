module cmd_proc(clk,rst_n,BMPL_n,BMPR_n,go,err_opn_lp,line_present,buzz,RX);

input clk,rst_n,BMPL_n,BMPR_n,RX,line_present;
output go,buzz;
output reg [15:0] err_opn_lp;

logic last_veer_right, nxt_cmd, cmd_rdy, cap_cmd, rst_tmr;
logic [15:0] cmd;
logic [1:0] cmd_reg;
logic [15:0] cmd_shft_reg;
logic [25:0] tmr;
logic REV_tmr1, REV_tmr2, BMP_DBNC_tmr;
logic shft;

parameter FAST_SIM = 0;

UART_wrapper UART(.cmd(cmd), .cmd_rdy(cmd_rdy), .clr_cmd_rdy(cap_cmd), .RX(RX), .clk(clk), .rst_n(rst_n));

always_ff @(posedge clk)begin 
	if(cap_cmd && shft) begin 
		cmd_shft_reg[15:0] = {2'b0 , cmd[15:2]}; 
	end else if(cap_cmd && !shft) begin 
		cmd_shft_reg[15:0] = cmd[15:0];
	end 
end 
assign cmd_reg[1:0] = cmd_shft_reg[1:0];

always_ff @(posedge clk, negedge rst_n) begin 
	if(!rst_n)
		last_veer_right = 0;
	else if(nxt_cmd)
		last_veer_right = cmd_reg[0];
end 

always_ff @(posedge clk) begin 
	if(rst_tmr)
		tmr = 0;
	else
		tmr = tmr + 1;
end 

typedef enum reg [2:0] { IDLE, READY, CLR_GO, ASSERT_ERR_OPN_LP_1,ASSERT_ERR_OPN_LP_2, RST_ERR_OPN_LP, ASSERT_LFT_RGHT_ERR,BUZZ_100MS, BUZZ, REGULAR_VEER} state_t;
state_t state, next_state;

  // SM flop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
	  
assign shft = nxt_cmd;
	  
always_comb begin 
	nxt_cmd = 0;
	cap_cmd = 0;
	err_opn_lp = 0;
	go = 0;
	rst_tmr = 0;
	buzz = 0;
	
	case (state) 
	
	IDLE : begin 
		if(cmd_rdy && line_present) begin 
			next_state = READY;
			cap_cmd = 1;
			go = 1;
		end else
			next_state = IDLE;
	end 
	
	READY : begin 
		if(line_present) begin 
			if(!BMPL_n || !BMPR_n) begin 
				go = 0;
				rst_tmr = 1;
				buzz = 1;
				next_state = BUZZ_100MS;
				if(BMPL_n && BMPR_n)
					next_state = READY;
				else
					next_state = BUZZ;
			end else
				next_state = READY;
		end else if(cmd[1:0] == 2'b11) begin 
			go = 0;
			next_state = ASSERT_ERR_OPN_LP_1;
		end else if(|cmd[1:0]) begin 
			next_state = REGULAR_VEER;
		end else begin 
			go = 0;
			next_state = IDLE;
		end 
	end
	
	REGULAR_VEER : begin 
		if(cmd[0]) 
			err_opn_lp = 16'h340;
		else
			err_opn_lp = -16'h340;
		if(line_present) begin 
			nxt_cmd = 1;
			next_state = READY;
		end else
			next_state = REGULAR_VEER;
	end
	
	ASSERT_ERR_OPN_LP_1 : begin 
		go = 1;
		if(last_veer_right) begin 
			rst_tmr = 1;
			if(!REV_tmr1) begin 
				err_opn_lp = -16'h1E0;
			end else begin 
				go = 0;
				next_state = ASSERT_ERR_OPN_LP_2;
			end 
		end else begin 
			rst_tmr = 1;
			if(!REV_tmr1) begin 
				err_opn_lp = 16'h1E0;
			end else begin 
				go = 0;
				next_state = ASSERT_ERR_OPN_LP_2;
			end 
		end
	end 
	
	ASSERT_ERR_OPN_LP_2 : begin 
		go = 1;
		if(last_veer_right) begin 
			rst_tmr = 1;
			if(!REV_tmr2) begin 
				err_opn_lp = 16'h380;
			end else begin 
				next_state = RST_ERR_OPN_LP;
			end 
		end else begin 
			rst_tmr = 1;
			if(!REV_tmr2) begin 
				err_opn_lp = -16'h380;
			end else begin 
				next_state = RST_ERR_OPN_LP;
			end 
		end
	end 
	
	RST_ERR_OPN_LP : begin 
		err_opn_lp = 0;
		if(line_present) begin
			nxt_cmd = 1;
			next_state = READY;
		end	else
			next_state = RST_ERR_OPN_LP;
	end 
	
	BUZZ_100MS : begin 
		if(BMP_DBNC_tmr) begin 
			if(BMPL_n && BMPR_n) begin 
				buzz = !buzz;
				next_state = READY;
			end else begin 
				next_state = BUZZ;
			end
		end else
			next_state = BUZZ_100MS;
	end 
	
	BUZZ : begin 
		if(BMPL_n && BMPR_n) begin 
			buzz = !buzz;
			next_state = READY;
		end else begin 
			next_state = BUZZ;
		end
	end 
	
	endcase
end 
 generate 
    if (FAST_SIM) begin
      assign REV_tmr1 = tmr[20:16] == 5'h0A ? 1'b1 : 1'b0;
      assign REV_tmr2 = tmr[25:21] == 5'h10 ? 1'b1 : 1'b0;
	  assign BMP_DBNC_tmr = &tmr[16:0];
    end else begin
      assign REV_tmr1 = tmr[20:16] == 5'h16 ? 1'b1 : 1'b0;
      assign REV_tmr2 = tmr[25:21] == 5'h1F ? 1'b1 : 1'b0;
	  assign BMP_DBNC_tmr = &tmr[21:0];
    end 
  endgenerate
endmodule 
