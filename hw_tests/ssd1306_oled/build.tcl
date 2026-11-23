# Non-project build of the 0.96" I2C OLED (SSD1306) compatibility test.
# Usage (from the repo root):
#   D:/Xilinx/Vivado/2019.2/bin/vivado.bat -mode batch -source hw_tests/ssd1306_oled/build.tcl
# Output: build/ssd1306_oled_test/ssd1306_oled_test.bit (build/ is git-ignored)

set here     [file dirname [file normalize [info script]]]
set repo     [file normalize [file join $here .. ..]]
set out_dir  [file join $repo build ssd1306_oled_test]
file mkdir $out_dir

read_verilog [file join $here rtl ssd1306_i2c_master.v]
read_verilog [file join $here rtl ssd1306_oled_test_top.v]
read_xdc     [file join $here constr ssd1306_oled_test.xdc]

synth_design -top ssd1306_oled_test_top -part xc7z020clg400-1
opt_design
place_design
route_design

report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization    -file [file join $out_dir utilization.rpt]
report_io             -file [file join $out_dir io.rpt]

write_bitstream -force [file join $out_dir ssd1306_oled_test.bit]

set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
set fh [open [file join $out_dir build_result.txt] w]
puts $fh "WNS=$wns"
close $fh
puts "INFO: build finished, WNS=$wns"
