module UART_tx(tx_done, TX, trmt, tx_data, clk, rst_n);

// Define our state machine states
typedef enum reg [1:0] {IDLE, START, TXS} state_t;
	state_t state, nxt_state;

// Input/output ports
input clk, rst_n, trmt;
input [7:0] tx_data;

output TX;
output reg tx_done;

// Flop registers
reg [12:0] baud_cnt;
reg [3:0] bit_cnt;
reg [9:0] tx_shft_reg;

reg load, shift, transmitting, clr_done, set_done; // State machine outputs

wire [1:0] load_and_shift;

assign load_and_shift = {load, shift};

// Bit counter
always_ff @(posedge clk)
	if(load)
		bit_cnt <= 4'h0;
	else if(shift)
		bit_cnt <= bit_cnt+1;

// Baud counter
always_ff @(posedge clk)
	if(load || shift)
		baud_cnt <= 13'h0000;
	else if(transmitting)
		baud_cnt <= baud_cnt+1;
	
assign shift = (baud_cnt == 13'h1458); // Assert shift when our baud counter reaches our clock cycles per baud (5208)

// Tx/shifting flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		tx_shft_reg <= 9'h1ff; // We need the TX line to be high when reset so the rcvr can detect the falling edge
	else if(load)
		tx_shft_reg <= {1'b1, tx_data, 1'b0};
	else if(shift)
		tx_shft_reg <= tx_shft_reg >> 1;

assign TX = tx_shft_reg[0]; //Transmit the next bit


// Transmitting status SR flop with async reset
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		tx_done <= 1'b0;
	else if(clr_done)
		tx_done <= 1'b0;
	else if(set_done)
		tx_done <= 1'b1;

// State machine state flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

// State machine next state logic	
always_comb begin
	// Default our next state and outputs
	nxt_state = IDLE;
	load = 0;
	transmitting = 0;
	clr_done = 0;
	set_done = 0;
	
	case(state)
		IDLE: if(trmt) begin
				nxt_state = START;
				clr_done = 1;
				load = 1;
			end
		START: begin
			nxt_state = TXS;
			transmitting = 1;
			end
		TXS: if(bit_cnt == 4'h9) begin // Once we have transmitted 9 bits we are done
				nxt_state = IDLE;
				set_done = 1;
			end else begin
				nxt_state = TXS;
				transmitting = 1;
			end
		default: nxt_state = IDLE;
	endcase
end
endmodule
	