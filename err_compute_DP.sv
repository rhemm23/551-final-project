module err_compute_DP(clk,en_accum,clr_accum,sub,sel,IR_R0,IR_R1,IR_R2,IR_R3,
                    IR_L0,IR_L1,IR_L2,IR_L3,error);
					
    input clk;							// 50MHz clock
    input en_accum,clr_accum;				// accumulator control signals
    input sub;							// If asserted we subtract IR reading
    input [2:0] sel;						// mux select for operand
    input [11:0] IR_R0,IR_R1,IR_R2,IR_R3; // Right IR readings from inside out
    input [11:0] IR_L0,IR_L1,IR_L2,IR_L3; // Left IR reading from inside out
  
  
    output reg signed [15:0] error;	// Error in line following, goes to PID
  
  
    //  compute the error with the weight
    wire [15:0] selIR;
    assign selIR =  (sel == 3'b000) ? ({4'h0, IR_R0}) :
                    (sel == 3'b001) ? ({4'h0, IR_L0}) :
                    (sel == 3'b010) ? ({3'h0, IR_R1, 1'h0}) :
                    (sel == 3'b011) ? ({3'h0, IR_L1, 1'h0}) :
                    (sel == 3'b100) ? ({2'h0, IR_R2, 2'h0}) :
                    (sel == 3'b101) ? ({2'h0, IR_L2, 2'h0}) :
                    (sel == 3'b110) ? ({1'h0, IR_R3, 3'h0}) : ({1'h0, IR_L3, 3'h0});
    
    // wire [15:0] signedSelIR;
    // wire [15:0] subVec;
    // assign subVec = ({ {15{sub}}, sub });
    // assign signedSelIR = subVec ^ selIR;

    wire signed [15:0] next_error;
    assign next_error = (sub) ? error - selIR : error + selIR; 
  
    //////////////////////////////////
    // Implement error accumulator //
    ////////////////////////////////
    always_ff @(posedge clk)
        if (clr_accum)
            error <= 16'h0000;
        else if (en_accum)
            error <= next_error; 

endmodule