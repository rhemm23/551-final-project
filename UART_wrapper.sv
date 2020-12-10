module UART_wrapper(cmd_rdy, clr_cmd_rdy, cmd, RX, clk, rst_n);

// Define our state machine states
typedef enum reg [1:0] {BYTE1, BYTE2} state_t;
	state_t state, nxt_state;

// Wrapper input and outputs
input clr_cmd_rdy, RX, clk, rst_n;
output logic [15:0] cmd;
output logic cmd_rdy;

// State machine input and outputs
wire rx_rdy;
wire [7:0] rx_data;
logic clr_rx_rdy, set_cmd_rdy, shft_byte;

// Instantiate UART receiver and connect to state machine
UART_rcv UART_rx(.clk(clk),.rst_n(rst_n),.RX(RX),.rdy(rx_rdy),.rx_data(rx_data),.clr_rdy(clr_rx_rdy));

// Cmd byte accumulator flop
always_ff @(posedge clk)
	if(shft_byte)
		cmd <= {cmd[7:0],rx_data[7:0]}; // Shift newly received data into cmd register if shift is asserted


// State machine state flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= BYTE1;
	else
		state <= nxt_state;

// Next state and output logic
always_comb begin
	// Default our next state and outputs
	nxt_state = BYTE1;
	clr_rx_rdy = 0;
	shft_byte = 0;
	set_cmd_rdy = 0;
	
	case(state)
		BYTE1: if(rx_rdy) begin // Wait for first byte to be received, doubles as our "idle" state
			shft_byte = 1; // Shift the first byte into our cmd register
			clr_rx_rdy = 1; // Acknowledge we received the data
			nxt_state = BYTE2;
		end
		BYTE2: if(rx_rdy) begin // Wait for the second byte to be received
			shft_byte = 1; // Shift the second byte into our cmd register
			clr_rx_rdy = 1; // Acknowledge we received the data
			set_cmd_rdy = 1; // Assert cmd is ready
			nxt_state = BYTE1;
		end else
			nxt_state = BYTE2;
		default: nxt_state = BYTE1;
	endcase

end

// SR Flop to control cmd_rdy to prevent it from glitching
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		cmd_rdy <= 0;
	else if(clr_cmd_rdy)
		cmd_rdy <= 0;
	else if(set_cmd_rdy)
		cmd_rdy <= 1;

endmodule
