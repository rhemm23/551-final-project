module err_compute_SM(sel, err_vld, IR_vld, clr_accum, en_accum, clk, rst_n);

	// Define our state machine states
	typedef enum reg [1:0] {IDLE, ERR, ACCUM} state_t;
		state_t state, nxt_state;


	// State machine inputs and outputs
	input IR_vld, clk, rst_n;
	output logic err_vld, clr_accum, en_accum;
	output logic [2:0] sel;
	
	logic inc_sel, clr_sel; // Internal signals for incrementing/clearing select signal counter

	// State machine state flop
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	
	// Error select signal counter
	// Counts which IR signal should be selected
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			sel <= 3'h0;
		else if(clr_sel)
			sel <= 3'h0;
		else if(inc_sel)
			sel <= sel + 1;

	// State machine next state logic	
	always_comb begin
		// Default our next state and outputs
		nxt_state = IDLE;
		err_vld = 0;
		clr_accum = 0;
		en_accum = 0;
		inc_sel = 0;
		clr_sel = 0;
		
		case(state)
			IDLE: if(IR_vld) begin // Begin when IR signals are valid
					nxt_state = ERR;
					clr_accum = 1; // Clear the previously accumulated value
				end
			ERR: begin
					nxt_state = ACCUM;
					en_accum = 1; // Immediately enable the accumulator in this state and transition to the accum state
				end
			ACCUM: if(sel == 3'h7) begin // Done accumulating error once we've selected all 8 IR signals
					nxt_state = IDLE;
					err_vld = 1; // Assert that the error is ready
					clr_sel = 1;
				end else begin // Otherwise accumulate error on the next (incremented) signal
					nxt_state = ERR;
					inc_sel = 1; // Increment select on return to ERR to avoid off by one error
				end
			default: nxt_state = IDLE; // No latches
		endcase
	end
endmodule
