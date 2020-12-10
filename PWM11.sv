module PWM11(PWM_sig, duty, rst_n, clk);

input [10:0] duty;
input rst_n, clk;
output logic PWM_sig;

wire PWM_unflopped;
logic [10:0] cnt;


assign PWM_unflopped = (duty > cnt) ? 1'b1 : 1'b0;

// D flip flops with async active low reset
always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			cnt <= 11'b0;
		else
			cnt <= cnt + 1'b1;
			
			
always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			PWM_sig <= 1'b0;
		else
			PWM_sig <= PWM_unflopped;

endmodule
