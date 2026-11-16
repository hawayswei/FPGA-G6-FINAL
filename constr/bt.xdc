## ============================================================================
## bt.xdc - course Bluetooth module (UART 9600 8N1) on Pmod A, bottom row
## Owner : integrator (only the integrator edits constraint files)
## Source: pin locations from the course file "PYNQ-Z2 v1.0.xdc" (ja[6], ja[7]).
##         Module pins RXD TXD GND VCC go to Pmod A pins 9, 10, 11, 12.
##         (In Lab 2-4 the module sat on the top row, pins 3-6. The top row is
##         now used by the Pmod ACL2.)
## ============================================================================

## Pmod A pin 9  -> module RXD  (FPGA transmits)
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports { bt_tx_o }]
## Pmod A pin 10 <- module TXD  (FPGA receives; pull-up keeps the line idle when unplugged)
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { bt_rx_i }]

set_false_path -to   [get_ports { bt_tx_o }]
set_false_path -from [get_ports { bt_rx_i }]
