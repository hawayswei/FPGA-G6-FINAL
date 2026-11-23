## 0.96" I2C OLED (SSD1306) compatibility test on PYNQ-Z2 (xc7z020clg400-1)
## OLED is wired to the Arduino header I2C pins (silkscreen SCL / SDA, next to
## AREF), so Pmod A/B (main project) and AR8..AR13 (LCD test) stay untouched.
## Not read by scripts/check.tcl.

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

## RGB LEDs (diagnostics)
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { led4_r_o }]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { led4_g_o }]
set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports { led4_b_o }]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led5_r_o }]
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { led5_g_o }]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led5_b_o }]

## OLED I2C, open-drain (RTL drives only 0 or Z). Both pins are inout because
## the diagnostic scan can swap the SCL/SDA roles. Internal pull-ups enabled as
## a backup; the OLED module's own pull-ups (to its 3.3 V supply) do the work.
## Measured 2026-11-17: with OLED SCL/SDA wired to the header holes labeled
## SCL/SDA, the OLED only ACKed with the roles swapped compared with the
## course file (which lists ar_scl = P16, ar_sda = P15). So SCL is on P15 and
## SDA on P16 here. Not yet cross-checked against the PYNQ-Z2 schematic.
## Arduino header SCL -> OLED SCL
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { oled_scl_io }]
## Arduino header SDA -> OLED SDA
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { oled_sda_io }]

## Slow asynchronous I/O: no timing requirement
set_false_path -from [get_ports { btn_i[*] sw_i[*] oled_scl_io oled_sda_io }]
set_false_path -to   [get_ports { led_o[*] led4_*_o led5_*_o oled_scl_io oled_sda_io }]
