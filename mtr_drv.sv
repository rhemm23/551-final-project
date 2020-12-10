module mtr_drv(PWML, PWMR, DIRL, DIRR, lft_duty, rght_duty, rst_n, clk);

input [11:0] lft_duty;
input [11:0] rght_duty;
input rst_n, clk;

wire [10:0] lft_mag;
wire [10:0] rght_mag;

output wire DIRL, DIRR;
output logic PWML;
output logic PWMR;

assign DIRL = lft_duty[11]; // Left motor direction
assign DIRR = rght_duty[11]; // Right motor direction

// If mtr_spd is negative, check if input is -2048 since this needs to be mapped to a magnitude of 2047 otherwise it'll overflow to 0
// otherwise get the magnitude of the negative number
assign lft_mag = DIRL ? ((lft_duty[10:0] == 11'd0) ? 11'd2047 : ~lft_duty[10:0]+1'b1) : lft_duty[10:0]; // Get the magnitude of the left motor speed
assign rght_mag = DIRR ? ((rght_duty[10:0] == 11'd0) ? 11'd2047 : ~rght_duty[10:0]+1'b1) : rght_duty[10:0]; // Get the magnitude of the left motor speed

PWM11 left_PWM(PWML, lft_mag, rst_n, clk); // Convert left duty to PWM signal
PWM11 right_PWM(PWMR, rght_mag, rst_n, clk); // Convert right duty to PWM signal

endmodule
