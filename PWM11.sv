module PWM11(clk, rst_n, duty, PWM_sig);

  input clk, rst_n;
  input[10:0] duty;
  
  // Output signal
  output reg PWM_sig;
  
  // Current count
  reg[10:0] cnt;

  // Increment cnt and compare, or set cnt to zero if reset
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
      cnt <= 1'b0;
      PWM_sig <= 1'b0;
    end else begin
      cnt <= cnt + 1;
      PWM_sig <= cnt < duty;
    end

endmodule
