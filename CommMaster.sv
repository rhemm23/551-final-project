module CommMaster(cmd_cmplt, TX, cmd, send_cmd, clk, rst_n);

// Define our state machine states
typedef enum reg [1:0] {IDLE, BYTE1, BYTE2} state_t;
	state_t state, nxt_state;

// Wrapper inputs and outputs
output TX;
output logic cmd_cmplt;
input send_cmd, clk,rst_n;
input [15:0] cmd;

// Cmd signals
reg [7:0] cmd_lower;
wire [7:0] cmd_sel;
wire tx_done;

logic trmt, sel; // State machine outputs to control UART_tx

// Instantiate our UART transmitter and connect to state machine
UART_tx tx(.tx_done(tx_done), .TX(TX), .trmt(trmt), .tx_data(cmd_sel), .clk(clk), .rst_n(rst_n));

// Flop to capture the 2nd tx cmd when snd_cmd is asserted
// 2nd cmd gets sent last so we can't rely on cmd being valid at that point in time anymore
always_ff @(posedge clk)
	if(send_cmd)
		cmd_lower <= cmd[7:0]; // Second byte of cmd
		
assign cmd_sel = sel ? cmd[15:8] : cmd_lower; // 2:1 mux to select either the first byte of cmd or second byte to transmit

// State machine state flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

// Next state and output logic
always_comb begin
	// Default our next state and outputs
	nxt_state = IDLE;
	sel = 1; // Select first byte by default
	trmt = 0;
	cmd_cmplt = 0;
	
	case(state)
		IDLE: if(send_cmd) begin // Begin transmission when snd_cmd is asserted
			sel = 1; // Select the first byte of the cmd to transmit
			trmt = 1;
			nxt_state = BYTE1;
		end
		BYTE1: if(tx_done) begin // Begin the transmission of the 2nd byte after the 1st is complete
			sel = 0; // Select the second byte of the cmd to transmit
			trmt = 1;
			nxt_state = BYTE2;
		end else
			nxt_state = BYTE1;
		BYTE2: if(tx_done) begin // Assert cmd_cmplt when the second and last byte is complete
			cmd_cmplt = 1;
			nxt_state = IDLE;
		end else
			nxt_state = BYTE2;
		default: nxt_state = IDLE;
	endcase

end
endmodule
