module rst_synch(clk, rst_n, RST_n);

  input RST_n, clk;

  output rst_n;

  reg ff1, ff2;

  always_ff @(negedge clk, negedge RST_n)
    if (!RST_n) begin
      ff1 <= 1'b0;
      ff2 <= 1'b0;
    end else begin
      ff1 <= 1'b1;
      ff2 <= ff1;
    end
    
  assign rst_n = ff2;

endmodule