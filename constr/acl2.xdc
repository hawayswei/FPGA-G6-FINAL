## ============================================================================
## acl2.xdc - Pmod ACL2 (ADXL362 accelerometer, SPI) on Pmod A, top row
## Owner : integrator (only the integrator edits constraint files)
## Source: pin locations from the course file "PYNQ-Z2 v1.0.xdc" (ja[0..3]).
##         Pmod ACL2 pinout: 1 = ~CS, 2 = MOSI, 3 = MISO, 4 = SCLK,
##         5 = GND, 6 = VCC (3.3 V). INT1 / INT2 (bottom row) are not used.
## ============================================================================

set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports { acl_cs_n_o }]
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports { acl_mosi_o }]
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { acl_miso_i }]
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports { acl_sclk_o }]

## SPI runs at about 1 MHz and MISO goes through a synchronizer, so these
## pins are not timed against the 125 MHz clock.
set_false_path -to   [get_ports { acl_cs_n_o acl_mosi_o acl_sclk_o }]
set_false_path -from [get_ports { acl_miso_i }]
