module mtr_drv(clk, rst_n, lft_duty, rght_duty, DIRL, DIRR, PWML, PWMR);

  input clk, rst_n;
  input[11:0] lft_duty, rght_duty;
  
  output PWML, PWMR, DIRL, DIRR;
  
  wire[10:0] abs_rght_duty, abs_lft_duty;

  // Calc right abs duty
  assign DIRR = rght_duty[11];
  assign abs_rght_duty = DIRR ? (~rght_duty[10:0]) : rght_duty[10:0];
  
  // Calc left abs duty
  assign DIRL = lft_duty[11];
  assign abs_lft_duty = DIRL ? (~lft_duty[10:0]) : lft_duty[10:0];
  
  // Setup right and left PWM
  PWM11 rght_PWM(.clk(clk), .rst_n(rst_n), .duty(abs_rght_duty), .PWM_sig(PWMR));
  PWM11 lft_PWM(.clk(clk), .rst_n(rst_n), .duty(abs_lft_duty), .PWM_sig(PWML));

endmodule
