## 1602A LCD compatibility test on PYNQ-Z2 (xc7z020clg400-1)
## LCD is wired to the Arduino digital header AR8..AR13, so Pmod A/B (used by
## the main project) stay untouched. Not read by scripts/check.tcl.

set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { sysclk_i }]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4} [get_ports { sysclk_i }]

set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { btn_i[0] }]
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { btn_i[1] }]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 } [get_ports { btn_i[2] }]
set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS33 } [get_ports { btn_i[3] }]
set_property -dict { PACKAGE_PIN M20 IOSTANDARD LVCMOS33 } [get_ports { sw_i[0] }]
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports { sw_i[1] }]

set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { led_o[0] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { led_o[1] }]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { led_o[2] }]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led_o[3] }]

## LCD (write-only, 4-bit mode). LCD pin numbers are the silkscreen 1..16.
## AR8  -> LCD pin 4  RS
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { lcd_rs_o }]
## AR9  -> LCD pin 6  E
set_property -dict { PACKAGE_PIN V18 IOSTANDARD LVCMOS33 } [get_ports { lcd_e_o }]
## AR10 -> LCD pin 11 D4
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { lcd_d_o[0] }]
## AR11 -> LCD pin 12 D5
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { lcd_d_o[1] }]
## AR12 -> LCD pin 13 D6
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { lcd_d_o[2] }]
## AR13 -> LCD pin 14 D7
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { lcd_d_o[3] }]

## Slow asynchronous I/O: no timing requirement
set_false_path -from [get_ports { btn_i[*] sw_i[*] }]
set_false_path -to   [get_ports { led_o[*] lcd_rs_o lcd_e_o lcd_d_o[*] }]
