# ============================================================================
# capture.tcl - record acceleration trials from the board through the ILA
#
# Runs in the Vivado Tcl Console (GUI) or in "vivado -mode tcl". The data
# travels over the same USB cable that programs the board (JTAG).
#
# Usage:
#     source D:/FPGA/FPGA-G6-FINAL/scripts/capture.tcl
#     cap_connect                    ;# once per session: connect + program
#     cap fall_front A 01            ;# record 10 s -> data/trials/fall_front_A_01.csv
#     cap adl_walk B 03 20           ;# record 20 s
#     cap_status                     ;# show what the board reports right now
#
# cap <action> <person> <number> [seconds]
#     action : fall_front fall_back fall_left fall_right adl_walk adl_sit
#              adl_stand ... (names starting with "fall" count as falls)
#     person : one letter or short name, no underscore
#     number : trial number, e.g. 01
#     seconds: 10 (default), 20, 40 or 80. Rounded up to the next size the
#              ILA supports (1024 / 2048 / 4096 / 8192 samples at 100 Hz).
# An existing file is never overwritten; pick the next number instead.
#
# NOTE: written without access to a board. The ILA property names follow the
# Vivado 2019.2 documentation; if a command fails, send the red message to
# the integrator.
# ============================================================================

set cap_script_dir [file dirname [file normalize [info script]]]
set cap_repo_root  [file dirname $cap_script_dir]
set cap_impl_dir   [file join $cap_repo_root vivado_prj guardian.runs impl_1]
set cap_out_dir    [file join $cap_repo_root data trials]

proc cap_connect {} {
    global cap_impl_dir
    set bit [file join $cap_impl_dir guardian_top.bit]
    set ltx [file join $cap_impl_dir guardian_top.ltx]
    if {![file exists $bit]} { error "Bitstream not found: $bit\nRun Generate Bitstream first." }
    if {![file exists $ltx]} { error "Probes file not found: $ltx\nRun Generate Bitstream first." }

    catch {open_hw_manager}
    if {[llength [get_hw_servers -quiet]] == 0} { connect_hw_server }
    if {[catch {current_hw_target} t] || $t eq ""} {
        if {[catch {open_hw_target} msg]} {
            error "Cannot find the board. Check the USB cable (PROG UART port) and the power switch.\n$msg"
        }
    }
    set dev [lindex [get_hw_devices xc7z020_1] 0]
    current_hw_device $dev
    set_property PROGRAM.FILE $bit $dev
    set_property PROBES.FILE $ltx $dev
    set_property FULL_PROBES.FILE $ltx $dev
    program_hw_devices $dev
    refresh_hw_device $dev
    if {[llength [get_hw_ilas -quiet]] == 0} {
        error "The board was programmed but no ILA was found. Is this the right bitstream?"
    }
    puts "CAPTURE: board programmed, ILA ready. Use: cap <action> <person> <number> \[seconds\]"
}

proc cap_ila {} {
    set ilas [get_hw_ilas -quiet]
    if {[llength $ilas] == 0} { error "No ILA. Run cap_connect first." }
    return [lindex $ilas 0]
}

proc cap {action person number {seconds 10}} {
    global cap_out_dir
    set ila [cap_ila]
    file mkdir $cap_out_dir
    set csv [file join $cap_out_dir "${action}_${person}_${number}.csv"]
    if {[file exists $csv]} {
        error "File already exists: $csv\nUse the next trial number (nothing was recorded)."
    }

    # ILA window sizes are powers of two; one stored point per 10 ms sample
    set depth 1024
    while {$depth < $seconds * 100 && $depth < 8192} { set depth [expr {$depth * 2}] }
    set real_s [expr {$depth / 100.0}]

    set_property CONTROL.CAPTURE_MODE BASIC $ila
    set_property CONTROL.DATA_DEPTH $depth $ila
    set_property CONTROL.TRIGGER_POSITION 0 $ila
    # store a point only when a new acceleration sample arrives
    set_property CAPTURE_COMPARE_VALUE eq1'b1 [get_hw_probes *accel_valid* -of_objects $ila]

    puts "CAPTURE: recording $real_s s -> [file tail $csv]   >>> DO THE ACTION NOW <<<"
    run_hw_ila -trigger_now $ila
    # timeout is in minutes; allow twice the expected time plus one minute
    wait_on_hw_ila -timeout [expr {int($real_s * 2 / 60) + 1}] $ila
    set data [upload_hw_ila_data $ila]
    write_hw_ila_data -csv_file -force $csv $data
    puts "CAPTURE: saved $csv"
}

proc cap_status {} {
    set ila [cap_ila]
    puts "ILA: [get_property NAME $ila]  max depth: [get_property CONTROL.MAX_DATA_DEPTH $ila]"
    puts "core status: [get_property STATUS.CORE_STATUS $ila]"
}

puts "capture.tcl loaded. Commands: cap_connect, cap <action> <person> <number> \[seconds\], cap_status"
