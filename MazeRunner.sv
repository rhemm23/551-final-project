module MazeRunner(clk,RST_n,SS_n,MOSI,MISO,SCLK,PWMR,PWML,
                  DIRR,DIRL,IR_EN,BMPL_n,BMPR_n,buzz,
				  buzz_n,RX,LED);

  input clk;		// 50MHz clock
  input RST_n;		// push button reset
  output SS_n;		// SS to ADC
  output MOSI;		// to ADC
  output SCLK;		// SCLK of SPI
  input MISO;		// from ADC
  output PWMR;		// motor speed right
  output PWML;		// motor speed left
  output DIRR;		// motor direction control Right
  output DIRL;		// motor direction control Left
  output IR_EN;		// Enables IR transmitter on IR sensors
  input BMPL_n;		// Left front bump switch
  input BMPR_n;		// Right front bump switch
  output buzz;		// buzzer 1.526kHz tone
  output buzz_n;
  input RX;			// UART in from BLE module
  output [7:0] LED;	// LEDs for debug
  
  //////////////////////////////////////////
  // Declare and needed internal signals //
  ////////////////////////////////////////
  wire rst_n;		// global reset signal
  wire send_resp;	// initiate sending of response to BLE
  wire cmd_rdy;		// indicates command ready from BLE
  wire [7:0] cmd;	// 16-bit command from BLE module
  wire clr_cmd_rdy;	// knocks down cmd_rdy
  
  wire [11:0] IR_R0,IR_R1,IR_R2,IR_R3;
  wire [11:0] IR_L0,IR_L1,IR_L2,IR_L3;
  wire moving;
  wire IR_vld;					// asserted for 1 clock when new line_pos valid
  wire line_present;		// indicates a line actually present
  wire err_vld;				// new error signal valid
  wire go;
  wire [15:0] err_raw;		// raw error as measured from IR array
  wire [15:0] err_opn_lp;	// term created by cmd_proc used to steer open loop mode
  wire [15:0] error;		// final error used by PID of line following
  wire signed [11:0] lft_spd,rght_spd;
  wire bmp_raw;				// combined bump signal (not yet synchronized)
  
  localparam FAST_SIM = 1;		// enable this when simulating fullchip in ModelSim
  
  /////////////////////////////////////
  // Instantiate reset synchronizer //
  ///////////////////////////////////
  rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));
  

  //////////////////////////////
  // Instantiate Motor Drive //
  ////////////////////////////
  mtr_drv iDRV(.clk(clk), .rst_n(rst_n), .lft_duty(lft_spd), .rght_duty(rght_spd), .DIRL(DIRL), .DIRR(DIRR), .PWML(PWML), .PWMR(PWMR));
  
  ///////////////////////////////////////////
  // Instantiate IR line sensor interface //
  /////////////////////////////////////////
  IR_intf #(.FAST_SIM(FAST_SIM)) iINTF(.clk(clk), .rst_n(rst_n), .IR_R0(IR_R0), .IR_R1(IR_R1), .IR_R2(IR_R2), .IR_R3(IR_R3), .IR_L0(IR_L0), .IR_L1(IR_L1), .IR_L2(IR_L2), .IR_L3(IR_L3), .IR_en(IR_EN), .IR_vld(IR_vld), .line_present(line_present), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));

  ////////////////////////////////
  // Instantiate error compute //
  //////////////////////////////
  err_compute iERR(.clk(clk), .rst_n(rst_n), .IR_vld(IR_vld), .IR_R0(IR_R0), .IR_R1(IR_R1), .IR_R2(IR_R2), .IR_R3(IR_R3), .IR_L0(IR_L0), .IR_L1(IR_L1), .IR_L2(IR_L2), .IR_L3(IR_L3), .error(err_raw), .err_vld(err_vld));

  ///////////////////////////////////////////////////////////////////
  // Instantiate cmd_proc block to receive & process command byte //
  /////////////////////////////////////////////////////////////////
  <-- Instantiate your cmd_proc (Don't forget to pass FAST_SIM to it) -->
						
  ////////////////////////////////////////////////////////////
  // To increase volume of buzzer we drive it differential //
  //////////////////////////////////////////////////////////  
  assign buzz_n = ~buzz;
  
  //////////////////////////////////////////////////////
  // Where did you put the mux that selects error to //
  // be err_raw from err_compute vs err_opn_lp?     //
  ///////////////////////////////////////////////////
  assign error = (line_present) ? err_raw : err_opn_lp;	// override error to effect veer left/right

  //////////////////////////////////////
  // Instantiate your PID controller //
  ////////////////////////////////////
  PID #(.FAST_SIM(FAST_SIM)) iPID(.clk(clk), .rst_n(rst_n), .lft_spd(lft_spd), .rght_spd(rght_spd), .moving(moving), .error(error), .err_vld(err_vld), .go(go), .line_present(line_present));
					 
		   
  assign LED = <-- there are 8 LEDs...do what you like...nothing is an option -->
   
  
  
endmodule
