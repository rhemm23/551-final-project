module A2D_intf(res, cnv_cmplt, strt_cnv, chnnl, SS_n, SCLK, MOSI, MISO, clk, rst_n);

// Define our state machine states
typedef enum reg [1:0] {IDLE, CMD1, WAIT, CMD2} state_t;
	state_t state, nxt_state;

// Interface inputs/outputs
input strt_cnv, clk, rst_n;
input [2:0] chnnl;

output logic cnv_cmplt;
output [11:0] res;

// SPI input/outputs
input MISO;
output SS_n, SCLK, MOSI;

// Intermediate signals
logic wrt, cmplt;
wire done;
wire [15:0] rd_data;

assign res[11:0] = ~rd_data[11:0]; // Result is the inverted lower 12 bits of A2D data

SPI_mstr16 spi(.cmd({2'b00, chnnl, 11'h000}), .wrt(wrt), .done(done), .rd_data(rd_data),
				.SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .clk(clk), .rst_n(rst_n));

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
	wrt = 0;
	cmplt = 0;
	
	case(state)
		IDLE: if(strt_cnv) begin  // Begin when start cnv is asserted
				nxt_state = CMD1;
				wrt = 1;          // Begin sending first command
			end
		CMD1: if(done)            // Wait for data to be received from SPI A2D
				nxt_state = WAIT;
			   else
				nxt_state = CMD1;
		WAIT: begin
				nxt_state = CMD2; // Wait one clock cycle before beginning next command
				wrt = 1;          // Begin sending next command
			end
		CMD2: if(done) begin      // Wait for data to be received from SPI A2D
				nxt_state = IDLE;
				cmplt = 1;        // We are done once A2D read is done
			end else begin
				nxt_state = CMD2;
			end
		default: nxt_state = IDLE;
	endcase

end

// Conversion complete flop to prevent signal from glitching and hold until next strt_cnv
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n) begin
		cnv_cmplt <= 0;
	end else if(strt_cnv) begin // On strt_cnv deassert complete signal from previous read
		cnv_cmplt <= 0;
	end else if(cmplt) begin // When state machine asserts complete, cnv_cmplt should be asserted
		cnv_cmplt <= 1;
	end

endmodule