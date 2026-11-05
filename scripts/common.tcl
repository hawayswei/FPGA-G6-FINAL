# ============================================================================
# common.tcl - helper procs shared by create_project.tcl and check.tcl
# Written for Tcl 8.5 (the version bundled with Vivado 2019.2).
# ============================================================================

# Recursively collect files matching a glob pattern below a directory.
proc glob_recursive {dir pattern} {
    set result {}
    foreach f [glob -nocomplain -types f -directory $dir $pattern] {
        lappend result $f
    }
    foreach d [glob -nocomplain -types d -directory $dir *] {
        set result [concat $result [glob_recursive $d $pattern]]
    }
    return $result
}

# Vivado 2019.2 is unreliable with non-ASCII characters (e.g. Chinese) in
# paths, and Windows limits path length. Stop early with a clear message.
proc assert_safe_path {path} {
    if {![string is ascii $path]} {
        error "Repo path contains non-ASCII characters (for example Chinese): $path\nMove the repo to an English-only path such as D:/FPGA/FPGA-G6-FINAL."
    }
    if {[string first " " $path] >= 0} {
        puts "WARNING: repo path contains a space: $path (avoid spaces if you can)"
    }
    if {[string length $path] > 60} {
        puts "WARNING: repo path is long ([string length $path] chars). Windows path-length limits may cause errors. Use a shorter path."
    }
}

# Project-wide constants (single place to change them)
set PRJ_NAME   pet
set FPGA_PART  xc7z020clg400-1
set TOP_MODULE pet_top
set SIM_TOP    tb_ctrl_heartbeat
