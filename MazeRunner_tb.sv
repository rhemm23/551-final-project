`timescale 1ns/1ns 
module MazeRunner_tb();

	localparam TOLERANCE = 10;        // Tolerance allowed between robot heading and line heading is 1 degree
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
	
	// State machine outputs/inputs
	reg go;                           // Asserted when a test should start
	reg obstructed;                   // Asserted when either bump switch is pressed
	reg signed [12:0] max_turn_theta; // Used to track robot angle during turn around maneuver
	reg signed [12:0] nxt_line_theta; // Angle of next line to load once current line is done
	integer clks_since_maneuver;      // Clock counter every time the robot does something
	reg last_veered_right;            // Asserted if robot last veered right, used to determine correct turn around behavior
	reg done_validating_maneuver;     // Asserted when the testbench has finished validating the current maneuver and is ready to validate next maneuver
	reg [15:0] current_command;       // Stores the travel plan for the current test with the current command at lowest 2 bits
	
	reg [12:0] test;
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
		

	initial begin
		clk = 0;
		
		$monitor("\nMazeRunner (t=%0t): %0s", $time, state.name());
		
		test_gap_turn_around1();
		$stop;
	end
	
	task test_follow_lines_basic();
		new_test(16'h0000); // Stop at end
		start_test();
		// Add here
		end_test();
		$display("YAHOO! Test passed");
	endtask
	
	task test_follow_lines_zigzag();
		new_test(16'h0000); // Stop at end
		start_test();
		// Add here
		end_test();
		$display("YAHOO! Test passed");
	endtask
	
	task test_gap_veer();
		new_test(16'h0009); // Veer right, then veer left, then stop
		start_test();
		// Add here
		end_test();
		$display("YAHOO! Test passed");
	endtask
	
	task test_gap_turn_around1();
		new_test(16'h000d); // Turn around twice (one cw other ccw)
		start_test();
		// Add here
		add_line(13'sd150);
		@(posedge done_validating_maneuver);
		add_gap();
		add_line(13'sd250);
		@(posedge done_validating_maneuver); // 2 maneuvers need to be checked after gap is added, the gap behavior itself
		@(posedge done_validating_maneuver); // and the line being followed after the gap is cleared
		add_gap();
		@(posedge done_validating_maneuver);
		@(posedge done_validating_maneuver);
		add_gap();
		//@(posedge done_validating_maneuver);
		end_test();
		$display("YAHOO! Test passed");
	endtask
	
	task test_gap_turn_around2();
		new_test(16'h000d); // Veer right and turn around, then veer left and turn around, then stop
		start_test();
		// Add here
		end_test();
		$display("YAHOO! Test passed");
	endtask
	
	task test_gap_stop();
		new_test(16'h0001); // Veer right then stop
		start_test();
		// Add here
		end_test();
		$display("YAHOO! Test passed");
	endtask
	
	task test_obstruction();
		new_test(16'h0000); // Stop at end
		start_test();
		// Add here
		end_test();
		$display("YAHOO! Test passed");
	endtask
	
	// The mega state machine controlling the simulation/validation of the MazeRunner
	// This is only a testbench so it doesn't really matter if this synthesizes correctly
	// Basically we're just using an always block to keep track of the MazeRunner's state
	// at any given point in time so we can continously check to make it sure it's doing what it's supposed to
	always @(posedge clk) begin
		nxt_state = RESET;
		RST_n = 1;
		done_validating_maneuver = 0;
		send_cmd = 0;
		
		case(state)
			RESET: begin
				RST_n = 0;
				nxt_state = STOPPED;
			end
			STOPPED: begin
				if(go) begin
					nxt_state = START;
				end else if(obstructed && BMPL_n && BMPR_n) begin
					line_theta = nxt_line_theta;
					line_present = 1;
					nxt_state = FOLLOWING_LINE;
				end else 
					nxt_state = STOPPED;
			end
			START: begin
				clks_since_maneuver = 0;
				obstructed = 0;
				line_theta = 0;
				line_present = 1;
				current_command = cmd;
				send_cmd = 1;
				nxt_state = FOLLOWING_LINE; // Sending cmd takes more than 1 clock cycle, so technically we transition to FOLLOWING_LINE before the MazeRunner has actually started moving but that's ok
			end
			FOLLOWING_LINE: begin
				clks_since_maneuver++;
				if(!line_present) begin
					//$display("Line lost t=%0t", $time);
					nxt_state = LOST_LINE;
				end else if(!BMPL_n || !BMPR_n) begin
					$display("Line obstructed t=%0t, next command %b", $time, current_command[1:0]);
					obstructed = 1;
					nxt_state = STOPPING;
				end else if(clks_since_maneuver == 1000000) begin
					// Check if steady state robot direction is valid
					if(!is_on_line()) begin
						$display("ERROR: MazeRunner not on line, line angle = %0d, robot angle = %0d", line_theta, iPHYS.theta_robot);
						$stop;
					end else begin
						$display("PASSED: MazeRunner following line, line angle = %0d, robot angle = %0d", line_theta, iPHYS.theta_robot);
					end
					//$display("Line complete t=%0t", $time);
					last_veered_right = (nxt_line_theta > line_theta) ? 1'b1 : 1'b0;
					line_theta = nxt_line_theta;
					done_validating_maneuver = 1; // Finished following this line, assert done for 1 clk
					clks_since_maneuver = 0; // Start new maneuver and clear the counter
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = FOLLOWING_LINE;
			end
			LOST_LINE: begin
				clks_since_maneuver = 0;
				// Determine line gap behavior
				case(current_command[1:0])
					2'b01 : begin // VEER RIGHT
						nxt_state = VEERING_RIGHT;
					end
					2'b10 : begin // VEER LEFT
						nxt_state = VEERING_LEFT;
					end
					2'b11 : begin // TURN AROUND
						max_turn_theta = iPHYS.theta_robot; // Begin tracking turn at starting theta
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
				if(clks_since_maneuver == 100000) begin
					// Check if robot is turning left (right motor > left motor)
					if(!is_veering_left()) begin
						$display("ERROR: Expected MazeRunner to be veering left");
						$stop;
					end else begin
						$display("PASSED: MazeRunner veered left");
					end
					nxt_state = VEERING_LEFT;
				end else if(abs(iPHYS.theta_robot - nxt_line_theta) <= SNAP_TO_LINE_TOL) begin
					line_theta = nxt_line_theta;
					line_present = 1;
					done_validating_maneuver = 1; // Finished veering, assert done for 1 clk
					clks_since_maneuver = 0; // Clear the counter
					last_veered_right = 0;
					nxt_state = FOLLOWING_LINE;
				end else if(clks_since_maneuver > 1000000) begin
					// Something broke if we are still veering after 1 mil clk
					// Stop simulation?
					done_validating_maneuver = 1;
					clks_since_maneuver = 0; // Clear the counter
					last_veered_right = 0;
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = VEERING_LEFT;
			end
			VEERING_RIGHT: begin
				clks_since_maneuver++;
				if(clks_since_maneuver == 100000) begin
					// Check if robot is turning right (right motor < left motor)
					if(!is_veering_right()) begin
						$display("ERROR: Expected MazeRunner to be veering right");
						$stop;
					end else begin
						$display("PASSED: MazeRunner veered right");
					end
					nxt_state = VEERING_RIGHT;
				end else if(abs(iPHYS.theta_robot - nxt_line_theta) <= SNAP_TO_LINE_TOL) begin
					//$display("Done veering %0d, %0d", iPHYS.theta_robot, nxt_line_theta);
					line_theta = nxt_line_theta;
					line_present = 1;
					done_validating_maneuver = 1; // Finished veering, assert done for 1 clk
					clks_since_maneuver = 0; // Clear the counter
					last_veered_right = 1;
					nxt_state = FOLLOWING_LINE;
				end else if(clks_since_maneuver > 2000000) begin
					// Something broke if we are still veering after 1 mil clk
					// Stop simulation?
					done_validating_maneuver = 1;
					clks_since_maneuver = 0; // Clear the counter
					last_veered_right = 1;
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = VEERING_RIGHT;
			end
			TURNING_AROUND: begin
				clks_since_maneuver++;
				// Track the robot's theta as the turn around is executed
				// We know the robot should turn +- 90 deg then -+ 270 deg
				if(last_veered_right && iPHYS.theta_robot < max_turn_theta) begin
					max_turn_theta = iPHYS.theta_robot;
				end else if(!last_veered_right && iPHYS.theta_robot > max_turn_theta) begin
					max_turn_theta = iPHYS.theta_robot;
				end
				// Let the robot turn 360 - SNAP degrees so it "sees" the line again
				test = abs(iPHYS.theta_robot - (line_theta - 1800));
				if(abs(iPHYS.theta_robot - (line_theta - 1800)) <= SNAP_TO_LINE_TOL) begin
					if(last_veered_right) begin
						if(!did_turn_ccw()) begin
							$display("ERROR: Expected MazeRunner to turn around CCW");
							$stop;
						end else begin
							$display("PASSED: MazeRunner turned around CCW (started at %0d, ended at %0d)", line_theta, (line_theta - 1800));
						end
					end else begin
						if(!did_turn_cw()) begin
							$display("ERROR: Expected MazeRunner to turn around CW");
							$stop;
						end else begin
							$display("PASSED: MazeRunner turned around CW (started at %0d, ended at %0d)", line_theta, (line_theta - 1800));
						end
					end
					//$display("Done turning around %0d, %0d", iPHYS.theta_robot, nxt_line_theta);
					line_theta = (line_theta - 1800); // New line theta is 180 deg opposite of the starting line (robot turned around)
					nxt_line_theta = line_theta;
					line_present = 1;
					done_validating_maneuver = 1; // Finished turning around, assert done for 1 clk
					clks_since_maneuver = 0; // Clear the counter
					//last_veered_right = 1;
					nxt_state = FOLLOWING_LINE;
				end else
					nxt_state = TURNING_AROUND;
			end
			STOPPING: begin
				clks_since_maneuver++;
				if(obstructed && clks_since_maneuver == 3000000) begin
					// Check if robot stopped and buzzers active
					if(!is_obstructed()) begin
						$display("ERROR: Expected MazeRunner to be obstructed (stopped and buzzing)");
						$stop;
					end
					done_validating_maneuver = 1; // Finished stopping, assert done for 1 clk
					clks_since_maneuver = 0; // Clear the counter
					nxt_state = STOPPED;
				end else if(!obstructed && clks_since_maneuver == 3000000) begin
					// Check if robot is stopped (both motors are at 0) on the line
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
	
	// Ready's the robot for a new test by resetting it to a known state
	// And giving it a new travel plan
	task new_test(input [15:0] travel_plan);
		//if(travel_plan[1:0] == 2'b11) begin
			//$display("ERROR: Veer command must preceed turn around");
			//$stop;
		//end
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
	
	task end_test();
		@(posedge done_validating_maneuver);
	endtask
	
	// Add a line with angle theta (tenths of degrees)
	task add_line(input signed [12:0] theta);
		if(theta - line_theta > 250 || theta - line_theta < -250) begin
			$display("ERROR: Bad line theta given, line must not change by more than 25 deg");
			$stop;
		end
		nxt_line_theta = theta;
		$display("Added a line with angle %0d deg", theta/10);
	endtask
	
	task add_gap();
		line_present = 0;
		$display("Added a gap");
		//@(posedge done_executing_maneuver);
	endtask
	
	task clear_gap();
		line_present = 1;
		$display("Cleared gap");
	endtask
	
	task add_obstruction_left();
		BMPL_n = 0;
		BMPR_n = 1;
		$display("Added an obstruction on the left side");
	endtask
	
	task add_obstruction_right();
		BMPL_n = 1;
		BMPR_n = 0;
		$display("Added an obstruction on the right side");
	endtask
	
	task add_obstruction_both();
		BMPL_n = 0;
		BMPR_n = 0;
		$display("Added an obstruction on both sides");
	endtask
	
	task clear_obstruction_left();
		BMPL_n = 1;
		$display("Cleared left obstruction");
	endtask
	
	task clear_obstruction_right();
		BMPR_n = 1;
		$display("Cleared right obstruction");
	endtask
	
	task clear_obstructions();
		BMPL_n = 1;
		BMPR_n = 1;
		$display("Cleared all obstructions");
	endtask
	
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
		did_turn_cw = is_moving() && abs((max_turn_theta - line_theta) - 900) < 200;
	endfunction
	
	function did_turn_ccw();
		did_turn_ccw = is_moving() && abs((max_turn_theta - line_theta) + 900) < 200;
	endfunction
	
	function is_moving();
		is_moving = iPHYS.omega_lft > 100 || iPHYS.omega_rght > 100 || iDUT.moving; // Moving is generated by PID and PID was already tested so we can "trust" it to validate MazeRunner
	endfunction
	
	// Function to compute absolute value
	function [12:0] abs(input signed [12:0] value);
		abs = (value < 0) ? -value : value;
	endfunction
	
	// Generate clock 100Mhz
	always
	  #5 clk = ~clk;
				  
endmodule