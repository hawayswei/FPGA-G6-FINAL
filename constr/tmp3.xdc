## ============================================================================
## tmp3.xdc - Pmod TMP3 temperature sensor (I2C, address 0x48) on Pmod B
## Owner : integrator (only the integrator edits constraint files)
## Source: same pins as Lab 3 / Lab 4: SCL = Pmod B pin 3, SDA = Pmod B pin 4,
##         pin 5 = GND, pin 6 = 3V3.
## ============================================================================

set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { tmp_scl_o }]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { tmp_sda_io }]

set_false_path -to   [get_ports { tmp_scl_o tmp_sda_io }]
set_false_path -from [get_ports { tmp_sda_io }]
