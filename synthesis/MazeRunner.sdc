###################################################################

# Created by write_sdc on Mon Dec  7 23:06:59 2020

###################################################################
set sdc_version 2.1

set_units -time ns -resistance MOhm -capacitance fF -voltage V -current uA
set_wire_load_model -name 16000 -library saed32rvt_tt0p85v25c
set_max_transition 0.15 [current_design]
set_driving_cell -lib_cell NAND2X2_RVT -library saed32rvt_tt0p85v25c           \
[get_ports MISO]
set_driving_cell -lib_cell NAND2X2_RVT -library saed32rvt_tt0p85v25c           \
[get_ports BMPL_n]
set_driving_cell -lib_cell NAND2X2_RVT -library saed32rvt_tt0p85v25c           \
[get_ports BMPR_n]
set_driving_cell -lib_cell NAND2X2_RVT -library saed32rvt_tt0p85v25c           \
[get_ports RX]
set_load -pin_load 0.1 [get_ports SS_n]
set_load -pin_load 0.1 [get_ports MOSI]
set_load -pin_load 0.1 [get_ports SCLK]
set_load -pin_load 0.1 [get_ports PWMR]
set_load -pin_load 0.1 [get_ports PWML]
set_load -pin_load 0.1 [get_ports DIRR]
set_load -pin_load 0.1 [get_ports DIRL]
set_load -pin_load 0.1 [get_ports IR_EN]
set_load -pin_load 0.1 [get_ports buzz]
set_load -pin_load 0.1 [get_ports buzz_n]
set_load -pin_load 0.1 [get_ports {LED[7]}]
set_load -pin_load 0.1 [get_ports {LED[6]}]
set_load -pin_load 0.1 [get_ports {LED[5]}]
set_load -pin_load 0.1 [get_ports {LED[4]}]
set_load -pin_load 0.1 [get_ports {LED[3]}]
set_load -pin_load 0.1 [get_ports {LED[2]}]
set_load -pin_load 0.1 [get_ports {LED[1]}]
set_load -pin_load 0.1 [get_ports {LED[0]}]
create_clock [get_ports clk]  -period 2.857  -waveform {0 1.4285}
set_clock_uncertainty 0.15  [get_clocks clk]
set_input_delay -clock clk  0.5  [get_ports RST_n]
set_input_delay -clock clk  0.5  [get_ports MISO]
set_input_delay -clock clk  0.5  [get_ports BMPL_n]
set_input_delay -clock clk  0.5  [get_ports BMPR_n]
set_input_delay -clock clk  0.5  [get_ports RX]
set_output_delay -clock clk  0.5  [get_ports SS_n]
set_output_delay -clock clk  0.5  [get_ports MOSI]
set_output_delay -clock clk  0.5  [get_ports SCLK]
set_output_delay -clock clk  0.5  [get_ports PWMR]
set_output_delay -clock clk  0.5  [get_ports PWML]
set_output_delay -clock clk  0.5  [get_ports DIRR]
set_output_delay -clock clk  0.5  [get_ports DIRL]
set_output_delay -clock clk  0.5  [get_ports IR_EN]
set_output_delay -clock clk  0.5  [get_ports buzz]
set_output_delay -clock clk  0.5  [get_ports buzz_n]
set_output_delay -clock clk  0.5  [get_ports {LED[7]}]
set_output_delay -clock clk  0.5  [get_ports {LED[6]}]
set_output_delay -clock clk  0.5  [get_ports {LED[5]}]
set_output_delay -clock clk  0.5  [get_ports {LED[4]}]
set_output_delay -clock clk  0.5  [get_ports {LED[3]}]
set_output_delay -clock clk  0.5  [get_ports {LED[2]}]
set_output_delay -clock clk  0.5  [get_ports {LED[1]}]
set_output_delay -clock clk  0.5  [get_ports {LED[0]}]
