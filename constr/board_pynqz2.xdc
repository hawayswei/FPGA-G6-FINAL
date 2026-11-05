## ============================================================================
## board_pynqz2.xdc - base constraints for the PYNQ-Z2 board
## Owner : integrator (only the integrator edits constraint files)
## Source: pin locations copied from the course file "PYNQ-Z2 v1.0.xdc".
##         Port names follow the team convention (_i / _o) and must match
##         the ports of rtl/top/pet_top.v.
## Rule  : Subsystem pins go in their own file (camera.xdc, hdmi.xdc,
##         servo.xdc, bt.xdc ...). Do not add them here.
## ============================================================================

## 125 MHz system clock
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { sysclk_i }]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sysclk_i }]

## Push buttons
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { btn_i[0] }]
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { btn_i[1] }]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 } [get_ports { btn_i[2] }]
set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS33 } [get_ports { btn_i[3] }]

## User LEDs
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { led_o[0] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { led_o[1] }]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { led_o[2] }]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led_o[3] }]
