module UART_rcv(rdy, rx_data, clr_rdy, RX, clk, rst_n);

// Define our state machine states
typedef enum reg [1:0] {IDLE, START, RXS} state_t;
	state_t state, nxt_state;

// Input/output ports
input clk, rst_n;
input reg clr_rdy;
output [7:0] rx_data;

input RX;
output reg rdy;

reg [12:0] baud_cnt;
reg [3:0] bit_cnt;
reg [8:0] rx_shft_reg;
reg RX_metastable, RX_stable, RX_previous;

reg start, shift, receiving, set_rdy; // State machine outputs

// Bit counter
always_ff @(posedge clk)
	if(start)
		bit_cnt <= 4'h0;
	else if(shift)
		bit_cnt <= bit_cnt+1;

// Baud counter
always_ff @(posedge clk)
	if(start)
		baud_cnt <= 13'h0000;
	else if(shift)
		baud_cnt <= 13'h0000;
	else if(receiving)
		baud_cnt <= baud_cnt+1;
	
assign shift = (baud_cnt == 13'h1458); // Assert shift when our baud counter reaches our clock cycles per baud (5208)

//------------------------------------------------------------------------
// Double flop RX since it is meta stable and not synchronized to our clock
always_ff @(posedge clk)
	RX_metastable <= RX;
	
always_ff @(posedge clk) begin
	RX_stable <= RX_metastable;
	RX_previous <= RX_stable; // Capture the previous value so we can detect a falling edge
end
//-------------------------------------------------------------------------

// Shifting/bit accumulator flop
always_ff @(posedge clk)
	if(shift)
		rx_shft_reg <= {RX_stable, rx_shft_reg} >> 1; // Shift in our new data little endian each time shift is asserted

assign rx_data = rx_shft_reg;


// Receiving status SR flop with async reset
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		rdy <= 1'b0;
	else if(clr_rdy || start)
		rdy <= 1'b0;
	else if(set_rdy)
		rdy <= 1'b1;

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
	start = 0;
	receiving = 0;
	set_rdy = 0;
	
	case(state)
		IDLE: if(!RX_stable && RX_previous) begin // Detect falling edge in RX
				nxt_state = START;
				start = 1;
			end
		START: begin
			nxt_state = RXS;
			receiving = 1;
			end
		RXS: if(bit_cnt == 4'h9) begin // Once our 9th bit is received, we are done
				nxt_state = IDLE;
				set_rdy = 1;
			end else begin
				nxt_state = RXS;
				receiving = 1;
			end
		default: nxt_state = IDLE; // No latches
	endcase
end
endmodule