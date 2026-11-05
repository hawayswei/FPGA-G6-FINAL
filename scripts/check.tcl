# ============================================================================
# check.tcl - quick "does the whole design still synthesize?" check
#
# Run through scripts/check.bat (double-click), or manually:
#     vivado -mode batch -source scripts/check.tcl
#
# Uses Vivado non-project mode: reads rtl/, ip/, constr/ straight from the
# repo, runs synthesis only, and writes build/check_result.txt (PASS / FAIL)
# plus build/check/utilization.rpt. Does not touch vivado_prj.
# ============================================================================

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]
source [file join $script_dir common.tcl]

set out_dir     [file join $repo_root build check]
set result_file [file join $repo_root build check_result.txt]
file mkdir $out_dir

proc write_result {path text} {
    set fh [open $path w]
    puts $fh $text
    close $fh
}

write_result $result_file "RUNNING"

if {[catch {
    assert_safe_path $repo_root

    set rtl_files [glob_recursive [file join $repo_root rtl] *.v]
    if {[llength $rtl_files] == 0} { error "No .v files found under rtl/" }
    read_verilog $rtl_files

    set xci_files [glob_recursive [file join $repo_root ip] *.xci]
    if {[llength $xci_files] > 0} {
        read_ip $xci_files
        generate_target all [get_ips]
        synth_ip [get_ips]
    }

    set xdc_files [glob -nocomplain -directory [file join $repo_root constr] *.xdc]
    foreach x $xdc_files { read_xdc $x }

    synth_design -top $TOP_MODULE -part $FPGA_PART
    report_utilization -file [file join $out_dir utilization.rpt]
} err]} {
    puts "CHECK FAILED: $err"
    write_result $result_file "FAIL: $err"
    exit 1
}

puts "CHECK PASSED: synthesis finished without errors."
write_result $result_file "PASS"
exit 0
