`timescale 1ns/1ns 
module MazeRunner_tb();

	localparam TOLERANCE = 15;        // Tolerance allowed between robot heading and line heading is 1.5 degrees
	localparam SNAP_TO_LINE_TOL = 50; // During gap maneuver, "snap" to next line when the angle is within this tolerance
									  // Instead of trying to manually time this, let the TB's state machine take care of it

	reg clk,RST_n;
	reg send_cmd;					// assert to send travel plan via CommMaster
	reg [15:0] cmd;					// traval plan command word to maze runner
	reg signed [12:0] line_theta;	// angle of line (starts at zero)
	reg line_present;				// is there a line or a gap?
	reg BMPL_n, BMPR_n;				// bump switch inputs

	///////////////////////////////////////////////////////////////
	// Declare internals sigs between DUT and supporting blocks //
	/////////////////////////////////////////////////////////////
	wire SS_n,MOSI,MISO,SCLK;		// SPI bus to A2D
	wire PWMR,PWML,DIRR,DIRL;		// motor controls
	wire IR_EN;						// IR sensor enable
	wire RX_TX;						// comm line between CommMaster and UART_wrapper
	wire cmd_sent;					// probably don't need this
	wire buzz,buzz_n;				// hooked to piezo buzzer outputs
	
	
	
	// Define the states that our MazeRunner can be in while under test
	typedef enum reg [3:0] {RESET, STOPPED, START, FOLLOWING_LINE, LOST_LINE, VEERING_LEFT, VEERING_RIGHT, TURNING_AROUND, STOPPING} state_t;
	state_t state, nxt_state;
	
	// MazeRunner state machine validation/test registers
	reg go;                           // Asserted when a test should start
	reg obstructed;                   // Asserted when either bump switch is pressed
	reg signed [12:0] max_turn_theta; // Used to track robot angle during turn around maneuver
	reg signed [12:0] nxt_line_theta; // Angle of next line to load once current line is done
	integer clks_since_maneuver;      // Clock counter every time the robot does something
	reg last_veered_right;            // Asserted if robot last veered right, used to determine correct turn around behavior
	reg done_validating_maneuver;     // Asserted when the testbench has finished validating the current maneuver and is ready to validate next maneuver
	reg [15:0] current_command;       // Stores the travel plan for the current test with the current command at lowest 2 bits




    //////////////////////
	// Instantiate DUT //
	////////////////////
	MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
					.PWMR(PWMR),.PWML(PWML),.DIRR(DIRR),.DIRL(DIRL),.IR_EN(IR_EN),
					.BMPL_n(BMPL_n),.BMPR_n(BMPR_n),.buzz(buzz),.buzz_n(buzz_n),.RX(RX_TX),
					.LED());
					
	////////////////////////////////////////////////
	// Instantiate Physical Model of Maze Runner //
	//////////////////////////////////////////////
	MazePhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
	                  .PWMR(PWMR),.PWML(PWML),.DIRR(DIRR),.DIRL(DIRL),.IR_EN(IR_EN),
					  .line_theta(line_theta),.line_present(line_present));
					  
	/////////////////////////////
	// Instantiate CommMaster //
	///////////////////////////
	CommMaster iMST(.clk(clk), .rst_n(RST_n), .TX(RX_TX), .send_cmd(send_cmd), .cmd(cmd),
                    .cmd_cmplt(cmd_sent));					  
		

	// Run all tests sequentially
	initial begin
		clk = 0;
		
		// Display which state the MazeRunner is in to better understand what's happening
		$monitor("\nMazeRunner (t=%0t): %0s", $time, state.name()); 
		
		//test_follow_lines();
		//test_gap_veer();
		//test_gap_turn_around1();
		test_obstructions();
		
		$display("YAHOO! All tests passed!");
		$stop;
	end
	
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	//   MAZERUNNER TEST SCENARIOS
	//
	
	// WARNING This test takes like 5 minutes to run in ModelSim
	// Only run if you don't value your time
	// Define the line angles we want to test, 
	// Taking it through the full range -360 to +360 ensures the PID controller is exercised
	// and there is no error in the system that accumulates over a long-running test
	int line_thetas[0:49] = {80, 10, -110, -360, -610, -860, -1110,
							-1360, -1610, -1860, -2110, -2360, -2610,
							-2860, -3110, -3360, -3600, -3350, -3100,
							-2850, -2600, -2350, -2100, -1850, -1600,
							-1350, -1100, -850, -600, -350, -100,
							70, -30, -50, 10, 200, 450, 700, 950,
							1200, 1450, 1700, 1950, 2200, 2450, 2700,
							2950, 3200, 3450, 3600};
	task test_follow_lines();
		$display("==========================================");
		$display("Running test: FOLLOW LINES");
		new_test(16'h0000); // Stop at end
		start_test();

		foreach(line_thetas[i]) begin
			add_line(line_thetas[i]);
			@(posedge done_validating_maneuver);
		end
		
		@(posedge done_validating_maneuver);
		add_gap();
		end_test();
		$display("YAHOO! Test passed");
		$display("==========================================\n");
	endtask
	
	task test_gap_veer();
		$display("==========================================");
		$display("Running test: VEER");
		new_test(16'h0169); // Veer right, veer left 2x, veer right 2x, then stop
		start_test();
		@(posedge done_validating_maneuver);
		
		add_gap();
		//add_line(13'sd50);
		@(posedge done_validating_maneuver); // 2 maneuvers need to be checked after gap is added, the gap behavior itself
		@(posedge done_validating_maneuver); // and the line being followed after the gap is cleared
		
		add_gap();
		//add_line(13'sd0);
		@(posedge done_validating_maneuver);
		@(posedge done_validating_maneuver);
		
		add_gap();
		//add_line(-13'sd100);
		@(posedge done_validating_maneuver);
		@(posedge done_validating_maneuver);
		
		add_gap();
		//add_line(13'sd75);
		@(posedge done_validating_maneuver);
		@(posedge done_validating_maneuver);
		
		add_gap();
		//add_line(13'sd300);
		@(posedge done_validating_maneuver);
		@(posedge done_validating_maneuver);
		
		add_gap();
		end_test();
		$display("YAHOO! Test passed");
		$display("==========================================\n");
	endtask
	
	// Test flow with travel plan: veer right, turn around, stop
	// follow 0 deg starting line -> follow 15 deg line -> gap -> veer right onto 25 deg line -> 
	// follow 25 deg line -> gap -> turn around CCW onto -155 deg line -> follow -155 deg line ->
	// gap -> stop
	task test_gap_turn_around1();
		$display("==========================================");
		$display("Running test: TURN AROUND 1");
		new_test(16'h00ed); // Turn around twice (first ccw, next cw)
		start_test();
		
		add_line(13'sd150);
		for(int i = 0; i < 4; i++) begin
			@(posedge done_validating_maneuver);
			@(posedge done_validating_maneuver);
			add_gap();
		end
		
		end_test();
		$display("YAHOO! Test passed");
		$display("==========================================\n");
	endtask
	
	task test_gap_turn_around2();
		$display("==========================================");
		$display("Running test: TURN AROUND 2");
		new_test(16'h000d); // Veer right and turn around, then veer left and turn around, then stop
		start_test();
		// Add here
		end_test();
		$display("YAHOO! Test passed");
		$display("==========================================\n");
	endtask
	
	task test_gap_stop1();
		$display("==========================================");
		$display("Running test: STOP 1");
		new_test(16'h0000); // Stop at first gap
		start_test();
		
		for(int i = 0; i < 3; i++) begin
			@(posedge done_validating_maneuver);
			@(posedge done_validating_maneuver);
			add_gap();
		end
		
		end_test();
		$display("YAHOO! Test passed");
		$display("==========================================\n");
	endtask
	
	task test_gap_stop2();
		$display("==========================================");
		$display("Running test: STOP 2");
		new_test(16'h0005); // Veer right twice then stop
		start_test();
		
		add_line(-13'sd100);
		for(int i = 0; i < 3; i++) begin
			@(posedge done_validating_maneuver);
			@(posedge done_validating_maneuver);
			add_gap();
		end
		
		end_test();
		$display("YAHOO! Test passed");
		$display("==========================================\n");
	endtask
	
	task test_obstructions();
		$display("==========================================");
		$display("Running test: OBSTRUCTIONS");
		new_test(16'h0000); // Stop at end
		start_test();
		
		add_line(13'sd180);
		@(posedge done_validating_maneuver);
		@(posedge done_validating_maneuver);
		
		add_obstruction_left();
		@(posedge done_validating_maneuver);
		clear_obstructions();
		
		add_line(13'sd300);
		@(posedge done_validating_maneuver);
		
		add_obstruction_right();
		@(posedge done_validating_maneuver);
		clear_obstructions();
		
		add_line(13'sd300);
		@(posedge done_validating_maneuver);
		
		// Manually check that if both bump switches are pressed
		// the robot doesn't begin moving until both are released
		add_obstruction_both();
		@(posedge done_validating_maneuver);
		clear_obstruction_left();
		repeat(100000) @(posedge clk);
		
		if(!is_obstructed()) begin
			$display("ERROR: Expected MazeRunner to be obstructed (one bump switch still pressed)");
			$stop;
		end else
			$display("PASSED: MazeRunner still obstructed");
			
		end_test();
		$display("YAHOO! Test passed");
		$display("==========================================\n");
	endtask
	
	//
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//
	//    MAZERUNNER VALIDATION STATE MACHINE
	//
	// The mega state machine controlling the validation of the MazeRunner
	//
	// Basically we're just using an always block to keep track of the MazeRunner's state
	// at any given point in time so we can continously check to make it sure it's doing what it's supposed to
	
	always @(posedge clk) begin
		nxt_state = RESET;
		RST_n = 1;
		done_validating_maneuver = 0;
		//send_cmd = 0;
		
		case(state)
		
			RESET: begin
				RST_n = 0;
				nxt_state = STOPPED;
			end
			
			
			STOPPED: begin
				if(go) begin
					nxt_state = START;
				end else if(obstructed && BMPL_n && BMPR_n) begin
					$display("PASSED: Obstruction was removed and MazeRunner began moving");
					line_theta = nxt_line_theta;
					line_present = 1;
					nxt_state = FOLLOWING_LINE;
				end else 
					nxt_state = STOPPED;
			end
			
			
			START: begin
				// Begin following starting line (0 deg)
				clks_since_maneuver = 0;
				obstructed = 0;
				line_theta = 0;
				nxt_line_theta = 0;
				line_present = 1;
				current_command = cmd;
				//send_cmd = 1;
				nxt_state = FOLLOWING_LINE; // Sending cmd takes more than 1 clock cycle, so technically we transition to FOLLOWING_LINE before the MazeRunner has actually started moving but that's ok
			end
			
			
			FOLLOWING_LINE: begin
				clks_since_maneuver++;
				if(!line_present) begin
					nxt_state = LOST_LINE;
				end else if(!BMPL_n || !BMPR_n) begin // Check if obstruction was added
					obstructed = 1;
					nxt_state = STOPPING;
				end else if(clks_since_maneuver == 1000000) begin // Check if steady state robot direction is valid
				
					if(!is_on_line()) begin
						$display("ERROR: MazeRunner not on line, line angle = %0d, robot angle = %0d", line_theta, iPHYS.theta_robot);
						$stop;
					end else begin
						$display("PASSED: MazeRunner following line, line angle = %0d, robot angle = %0d", line_theta, iPHYS.theta_robot);
					end
					
					// Start following next line
					//last_veered_right = (nxt_line_theta > line_theta) ? 1'b1 : 1'b0;
					line_theta = nxt_line_theta;
					done_validating_maneuver = 1; // Finished following this line, assert done for 1 clk
					clks_since_maneuver = 0;      // Clear the counter
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = FOLLOWING_LINE;
			end
			
			
			LOST_LINE: begin
				clks_since_maneuver = 0;
				// Determine expected line gap behavior
				case(current_command[1:0])
					2'b01 : begin // VEER RIGHT
						nxt_state = VEERING_RIGHT;
					end
					2'b10 : begin // VEER LEFT
						nxt_state = VEERING_LEFT;
					end
					2'b11 : begin // TURN AROUND
						max_turn_theta = iPHYS.theta_robot; // Begin tracking turn at current theta
						nxt_state = TURNING_AROUND;
					end
					default: begin  // STOP OR ANYTHING ELSE
						nxt_state = STOPPING;
					end		
				endcase
				current_command = current_command >> 2; // Load next command into LSBs of current_command
			end
			
			
			VEERING_LEFT: begin
				clks_since_maneuver++;
				if(clks_since_maneuver == 400000) begin
				
					// Check if robot is turning left (right motor > left motor)
					if(!is_veering_left()) begin
						$display("ERROR: Expected MazeRunner to be veering left");
						$stop;
					end else begin
						$display("PASSED: MazeRunner veered left");
					end
					
					// Follow new line - 35 deg
					line_theta = line_theta - 350;
					nxt_line_theta = line_theta;
					line_present = 1;
					done_validating_maneuver = 1; // Finished veering, assert done for 1 clk
					clks_since_maneuver = 0;      // Clear the counter
					last_veered_right = 0;        // No, this is a veer left
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = VEERING_LEFT;
			end
			
			
			VEERING_RIGHT: begin
				clks_since_maneuver++;
				if(clks_since_maneuver == 400000) begin
				
					// Check if robot is turning right (right motor < left motor)
					if(!is_veering_right()) begin
						$display("ERROR: Expected MazeRunner to be veering right");
						$stop;
					end else begin
						$display("PASSED: MazeRunner veered right");
					end
					
					// Follow new line + 35 deg
					line_theta = line_theta + 350;
					nxt_line_theta = line_theta;
					line_present = 1;
					done_validating_maneuver = 1; // Finished veering, assert done for 1 clk
					clks_since_maneuver = 0;      // Clear the counter
					last_veered_right = 1;        // Yes, this is a veer right
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = VEERING_RIGHT;
			end
			
			
			TURNING_AROUND: begin
				clks_since_maneuver++;
				// Track the robot's theta as the turn around is executed
				// We know the robot should turn +- 90 deg then -+ 270 deg
				if(!last_veered_right && iPHYS.theta_robot < max_turn_theta) begin
					max_turn_theta = iPHYS.theta_robot;
				end else if(last_veered_right && iPHYS.theta_robot > max_turn_theta) begin
					max_turn_theta = iPHYS.theta_robot;
				end
				
				// Let the robot turn ~360 so it "sees" the line again
				// If last veered right, check if robot has ended up -180 of starting position, or +180 if last veered left
				if((last_veered_right && (abs(iPHYS.theta_robot - (line_theta - 1800)) <= SNAP_TO_LINE_TOL)) || (!last_veered_right && (abs(iPHYS.theta_robot - (line_theta + 1800)) <= SNAP_TO_LINE_TOL))) begin
				
					// New line theta is 180 deg opposite of the starting line (robot turned around)
					nxt_line_theta = last_veered_right ? (line_theta - 1800) : (line_theta + 1800);
					
					// Check if turn around behavior was correct
					if(last_veered_right) begin
						if(!did_turn_ccw()) begin
							$display("ERROR: Expected MazeRunner to turn around CCW");
							$stop;
						end else begin
							$display("PASSED: MazeRunner turned around CCW (started at %0d, ended at %0d)", line_theta, nxt_line_theta);
						end
					end else begin
						if(!did_turn_cw()) begin
							$display("ERROR: Expected MazeRunner to turn around CW");
							$stop;
						end else begin
							$display("PASSED: MazeRunner turned around CW (started at %0d, ended at %0d)", line_theta, nxt_line_theta);
						end
					end
					
					// Pick up the line again
					line_theta = nxt_line_theta;
					line_present = 1;
					done_validating_maneuver = 1; // Finished turning around, assert done for 1 clk
					clks_since_maneuver = 0; // Clear the counter
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = TURNING_AROUND;
			end
			
			
			STOPPING: begin
				clks_since_maneuver++;
				if(obstructed && clks_since_maneuver == 2500000) begin // Check steady state if robot is obstructed
				
					// Check if robot is stopped and buzzer active
					if(!is_obstructed()) begin
						$display("ERROR: Expected MazeRunner to be obstructed (stopped and buzzing)");
						$stop;
					end else
						$display("PASSED: MazeRunner is stopped due to an obstruction");
					done_validating_maneuver = 1; // Finished stopping, assert done for 1 clk
					clks_since_maneuver = 0; // Clear the counter
					nxt_state = STOPPED;
					
				end else if(!obstructed && clks_since_maneuver == 2500000) begin // Check steady state if robot stopped due to command
					// Check if robot is stopped on the line
					if(is_moving() || !is_on_line()) begin
						$display("ERROR: Expected MazeRunner to be stopped on the line");
						$stop;
					end else begin
						$display("PASSED: MazeRunner is stopped");
					end
					done_validating_maneuver = 1; // Finished stopping, assert done for 1 clk
					clks_since_maneuver = 0; // Clear the counter
					nxt_state = STOPPED;
				end else
					nxt_state = STOPPING;
			end
		
		endcase
		
		state = nxt_state; // This state machine is for simulation only so it doesn't matter that we are combining the logic here
	
	end
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////
	//
	//    TEST BUILDER TASKS
	//
	
	// Ready's the robot for a new test by resetting it to a known state
	// and gives it a new travel plan
	task new_test(input [15:0] travel_plan);
		if(travel_plan[1:0] == 2'b11) begin
			$display("ERROR: Veer command must preceed turn around");
			$stop;
		end
		state = RESET;
		repeat(4) @(posedge clk);
		cmd = travel_plan;
		send_cmd = 1;
		repeat(4) @(posedge clk);
		send_cmd = 0;
	endtask
	
	// Begins a test by asserting go (which asserts send_cmd in the state machine)
	task start_test();
		go = 1;
		repeat(4) @(posedge clk);
		go = 0;
	endtask
	
	// Ends test by waiting for final maneuver to complete
	task end_test();
		@(posedge done_validating_maneuver);
	endtask
	
	// Adds a line with angle theta (tenths of degrees)
	task add_line(input signed [12:0] theta);
		if(theta - line_theta > 250 || theta - line_theta < -250) begin
			$display("ERROR: Bad line theta given, line must not change by more than 25 deg");
			$stop;
		end
		nxt_line_theta = theta;
		$display("Added a line with angle %0d deg", theta/10);
	endtask
	
	// Adds a gap by deasserting line_present
	task add_gap();
		line_present = 0;
		$display("Added a gap");
	endtask
	
	// Clears a gap manually
	// Proper gap timings are already coded into the state machine
	// This should only be used for specific scenarios
	// where custom timing is needed
	task clear_gap();
		line_present = 1;
		$display("Cleared gap");
	endtask
	
	// Adds an obstruction to the left bump switch
	task add_obstruction_left();
		BMPL_n = 0;
		BMPR_n = 1;
		$display("Added an obstruction on the left side");
	endtask
	
	// Adds an obstruction to the right bump switch
	task add_obstruction_right();
		BMPL_n = 1;
		BMPR_n = 0;
		$display("Added an obstruction on the right side");
	endtask
	
	// Adds an obstruction to both bump switches
	task add_obstruction_both();
		BMPL_n = 0;
		BMPR_n = 0;
		$display("Added an obstruction on both sides");
	endtask
	
	// Removes the obstruction from the left bump switch (if there even is one)
	task clear_obstruction_left();
		BMPL_n = 1;
		$display("Cleared left obstruction");
	endtask
	
	// Removes the obstruction from the right bump switch (if there even is one)
	task clear_obstruction_right();
		BMPR_n = 1;
		$display("Cleared right obstruction");
	endtask
	
	// Removes obstructions from both bump switchs (if there even is any)
	task clear_obstructions();
		BMPL_n = 1;
		BMPR_n = 1;
		$display("Cleared all obstructions");
	endtask
	
	//
	///////////////////////////////////////////////////////////////////////////////////////////
	
	
	///////////////////////////////////////////////////////////////////////////////////////////
	//
	//    BEHAVIOR VALIDATION FUNCTIONS
	//
	
	function is_obstructed();
		is_obstructed = is_on_line() && (buzz >= 1'b1) && !is_moving();
	endfunction
	
	function is_on_line();
		is_on_line = abs(iPHYS.theta_robot - line_theta) <= TOLERANCE;
	endfunction
	
	function is_veering_left();
		is_veering_left = iPHYS.omega_lft < iPHYS.omega_rght; // Veering left if right motor is spinning faster than left motor
	endfunction
	
	function is_veering_right();
		is_veering_right = iPHYS.omega_lft > iPHYS.omega_rght; // Veering right if right motor is spinning slower than left motor
	endfunction
	
	function did_turn_cw();
		did_turn_cw = is_moving() && abs((max_turn_theta - line_theta) + 900) < 350;
	endfunction
	
	function did_turn_ccw();
		did_turn_ccw = is_moving() && abs((max_turn_theta - line_theta) - 900) < 350;
	endfunction
	
	function is_moving();
		is_moving = iPHYS.omega_lft > 100 || iPHYS.omega_rght > 100 || iDUT.moving; // Moving is generated by PID and PID was already tested so we can "trust" it to validate MazeRunner
	endfunction
	
	// Function to compute absolute value
	function [12:0] abs(input signed [12:0] value);
		abs = (value < 0) ? -value : value;
	endfunction
	
	//
	/////////////////////////////////////////////////////////////////////////////////////////////
	
	// Generate clock 100Mhz
	always
	  #5 clk = ~clk;
				  
endmodule