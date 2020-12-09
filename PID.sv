///////////////////////////////////////////////
// Team: Yahoo! Test Passed!                 //
// Members:                                  //
// Oscar Zhang, Ryan Hemmila,                //
// Sai Chityala, Mason Berres                //
///////////////////////////////////////////////


module PID(lft_speed, rght_speed, moving, error, err_vld, go, line_present, clk, rst_n);

	parameter FAST_SIM = 0;      // Set to 1 to ramp up forward speed 8x faster (useful in ModelSim)

	localparam P_coeff = 7'h06;  // Coefficient for Proportional term of PID 1/6
	localparam I_coeff = 7'h00;  // Coefficient for Integral term of PID 1/2
	localparam D_coeff = 7'h38;  // Coefficient for Derivative term of PID 26

	output [11:0] lft_speed;     // Left motor speed
	output [11:0] rght_speed;    // Right motor speed
	output wire moving;          // Set to 1 if forward speed is above threshold to enable steering control

	input [15:0] error;
	input err_vld, go, line_present;

	input clk, rst_n;

	reg [10:0] FRWRD;            // Register to store our forward speed

	// PID signals comprising the total PID term
	reg signed [14:0] P_term;
	reg signed [9:0] I_term;
	reg signed [14:0] D_term;
	
	//reg signed [14:0] P_term_flopped;
	//reg signed [9:0] I_term_flopped;
	//reg signed [14:0] D_term_flopped;
	wire signed [14:0] PID;
	logic signed [14:0] PID_flopped;
	
	wire signed [11:0] FRWRD_sum;
	wire signed [11:0] FRWRD_diff;
	wire incr_en;
	
	// Sum each individual term into a PID signal
	// Zero when go is not asserted
	assign PID = go ? (P_term + {{5{I_term[9]}},I_term} + D_term) : 15'h0000;
	
	// Combinational logic for output signals
	assign moving = (FRWRD > 11'h080) ? 1'b1 : 1'b0; // Moving if speed is above 0x080
	assign lft_speed = moving ? FRWRD_sum : {1'b0, FRWRD}; // If not moving, motors should have same speed (don't steer when stopped)
	assign rght_speed = moving ? FRWRD_diff : {1'b0, FRWRD}; // Otherwise steer left and right based on PID output
	
	// Intermediate signal combinational logic
	assign FRWRD_sum = {1'b0, FRWRD} + PID_flopped[14:3]; // Ignore lower bits in PID term to divide effective value by 16
	assign FRWRD_diff = {1'b0, FRWRD} - PID_flopped[14:3];
	assign incr_en = err_vld && ~&FRWRD[9:8]; // Only increment speed when the error is valid or we are below max speed
	
	
	// Add pipelining flop to PID
	// to break up critical path
	always_ff @(posedge clk) begin
		PID_flopped <= PID;
	end
	
	// Forward speed incrementing flop
	// Generate the correct incrementing flop at compile time using FAST_SIM param
	generate
		if(FAST_SIM) begin
			always_ff @(posedge clk, negedge rst_n)
				if(!rst_n)
					FRWRD <= 11'h000;
				else if(!go)
					FRWRD <= 11'h000;
				else if(incr_en)
					FRWRD <= FRWRD + 11'h020;
		end else begin
			always_ff @(posedge clk, negedge rst_n)
				if(!rst_n)
					FRWRD <= 11'h000;
				else if(!go)
					FRWRD <= 11'h000;
				else if(incr_en)
					FRWRD <= FRWRD + 11'h004;
		end
	endgenerate


/////////////////////////////////////////////////////////////////////
	//  P TERM LOGIC
	
	wire signed [10:0] err_sat;
	logic signed [10:0] err_sat_flopped;

	// Saturate error to 11 bits. If error is negative and more negative than a 11 bit value, saturate it. If error is positive and larger than a 11 bit value, saturate it.
	//assign err_sat = error[15] ? (error[13:10] == 0 ? 11'b10000000000 : error[10:0]) : (error[13:10] == 0 ? error[10:0] : 11'b01111111111);
	assign err_sat = (!error[15] && |error[14:10]) ? 11'h3ff :
						(error[15] && ~&error[14:10]) ? 11'h400 :
						error[10:0];
	assign P_term = $signed(P_coeff)*err_sat_flopped; // Scale error by PID's P coefficient

/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
	//  D TERM LOGIC
	
	// Signals for computing D term
	logic signed [10:0] prev_err;
	wire signed [10:0] D_diff;
	wire signed [7:0] D_diff_sat;
	logic signed [7:0] D_diff_flopped;

	// Double flop the saturated error to capture the previous value needed for derivative
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) begin
			err_sat_flopped <= 11'h000;
			prev_err <= 11'h000;
		end else if(err_vld) begin
			err_sat_flopped <= err_sat;
			prev_err <= err_sat_flopped;
		end

	// Derivative should be change in error / change in time but change in time
	// Is the clock period so we can treat the deriv as just change in error
	assign D_diff = err_sat_flopped - prev_err;


	// Saturate derivative to 8 bits
	assign D_diff_sat = (!D_diff[10] && |D_diff[9:7]) ? 8'h7f :
						(D_diff[10] && ~&D_diff[9:7]) ? 8'h80 :
						D_diff[7:0];
	
	// Add pipelining flop after D_diff adder to break up a critical path
	// through the multiplier for D_term
	always_ff @(posedge clk) begin
		D_diff_flopped <= D_diff_sat;
	end

	// Scale error by PID's D coefficient
	assign D_term = $signed(D_coeff)*D_diff_flopped;
	
/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
	//  I TERM LOGIC
	
	logic signed [15:0] integrator;

    // inter-connected logic
    logic signed [15:0] ext_err_sat; // sign extended error saturation
    logic signed [15:0] temp_sum; // the sum before overflow checking
    logic signed [15:0] res_sum; // the sum after overflow checking 

    // select signal
    logic overflow_sel; // select based on overflow
    logic res_sel; // select based on positive edge

    // combinational logic 
    assign ext_err_sat = { {5{err_sat_flopped[10]}}, err_sat_flopped[10:0] };
    assign temp_sum = integrator + ext_err_sat; // adder output
    assign res_sum = (~overflow_sel && err_vld) ? temp_sum : integrator; // first mux
	assign I_term = $signed(I_coeff)*$signed(integrator[15:6]);
    
    // second mux is within the ff
    // ff
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            integrator <= 1'b0;
        else if (res_sel)
            integrator <= 1'b0;
        else
            integrator <= res_sum;
    
    // select signal combinational logics
    // determine the overflow
    always_comb begin
        overflow_sel = 0;
        if (ext_err_sat[15] == integrator[15] && ext_err_sat[15] != temp_sum[15]) begin
            overflow_sel = 1;
        end
    end

    // edge detection
    logic prev_line; // previous line present
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) 
            prev_line <= 1'b0;
        else
            prev_line <= line_present;
    
    // assign positive edge signal
    logic pos_edge; // positive edge signal
    assign pos_edge = (prev_line == 0) && (line_present == 1);

    // assign res_select singal
    assign res_sel = pos_edge | (~go) | (~moving);

/////////////////////////////////////////////////////////////////////


endmodule