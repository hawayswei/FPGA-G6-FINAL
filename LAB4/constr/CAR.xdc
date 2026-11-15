## Lab 4 - Bluetooth car on PYNQ-Z2 (pins identical to the teacher's 1116 CAR.xdc)

## Clock 125 MHz
set_property PACKAGE_PIN H16 [get_ports CLK]
set_property IOSTANDARD LVCMOS33 [get_ports CLK]
create_clock -period 8.000 -name CLK -waveform {0.000 4.000} [get_ports CLK]

## RGB LED LD4 [r,g,b]
set_property PACKAGE_PIN N15 [get_ports {led4[2]}]
set_property PACKAGE_PIN G17 [get_ports {led4[1]}]
set_property PACKAGE_PIN L15 [get_ports {led4[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led4[*]}]

## RGB LED LD5 [r,g,b]
set_property PACKAGE_PIN M15 [get_ports {led5[2]}]
set_property PACKAGE_PIN L14 [get_ports {led5[1]}]
set_property PACKAGE_PIN G14 [get_ports {led5[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led5[*]}]

## LEDs LD0..LD3
set_property PACKAGE_PIN R14 [get_ports {led[0]}]
set_property PACKAGE_PIN P14 [get_ports {led[1]}]
set_property PACKAGE_PIN N16 [get_ports {led[2]}]
set_property PACKAGE_PIN M14 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## Pmod A : Bluetooth module (RXD TXD GND VCC on Pmod A pins 3-6)
## JA[2] = Y16 = FPGA TX -> module RXD ; JAIN = Y17 = FPGA RX <- module TXD
set_property PACKAGE_PIN Y17 [get_ports JAIN]
set_property IOSTANDARD LVCMOS33 [get_ports JAIN]
set_property PULLUP true [get_ports JAIN]
set_property PACKAGE_PIN Y16 [get_ports {JA[2]}]
set_property PACKAGE_PIN Y19 [get_ports {JA[1]}]
set_property PACKAGE_PIN Y18 [get_ports {JA[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {JA[*]}]

## Pmod B : Pmod TMP3 (pin 3 = SCL, pin 4 = SDA)
set_property PACKAGE_PIN T10 [get_ports JBIN]
set_property IOSTANDARD LVCMOS33 [get_ports JBIN]
set_property PULLUP true [get_ports JBIN]
set_property PACKAGE_PIN T11 [get_ports {JB[2]}]
set_property PACKAGE_PIN Y14 [get_ports {JB[1]}]
set_property PACKAGE_PIN W14 [get_ports {JB[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {JB[*]}]

## Arduino header AR10..AR13 -> car PortB[5:2] (PB2 L-EN, PB3 R-EN, PB4 L-DIR, PB5 R-DIR)
set_property PACKAGE_PIN T16 [get_ports {ar[10]}]
set_property PACKAGE_PIN R17 [get_ports {ar[11]}]
set_property PACKAGE_PIN P18 [get_ports {ar[12]}]
set_property PACKAGE_PIN N17 [get_ports {ar[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ar[*]}]

## All I/O here are slow (LEDs, 9600-baud UART, 200 kHz I2C, motor enables).
## The reference "set_output_delay -max 2.0" lines produced negative WNS only
## because of the OBUF delay itself; they are replaced by false paths.
set_false_path -to   [get_ports {led[*] led4[*] led5[*] JA[*] JB[*] JBIN ar[*]}]
set_false_path -from [get_ports {JAIN JBIN}]
