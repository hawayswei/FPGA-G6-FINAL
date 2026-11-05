# ============================================================================
# create_project.tcl - build (or refresh) the local Vivado project
#
# Usage (Vivado Tcl Console; use forward slashes):
#     source D:/FPGA/FPGA-G6-FINAL/scripts/create_project.tcl
#
# Behaviour:
#   * First run : creates <repo>/vivado_prj/pet.xpr and adds every source file
#                 by REFERENCE (files stay in the repo; nothing is copied).
#   * Later runs: opens the project, adds files that appeared after a pull,
#                 and removes entries whose files were deleted. Safe to run
#                 after every "Update from main".
# The vivado_prj folder is git-ignored. Never commit it.
# ============================================================================

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]
source [file join $script_dir common.tcl]
assert_safe_path $repo_root

set prj_dir  [file join $repo_root vivado_prj]
set prj_file [file join $prj_dir ${PRJ_NAME}.xpr]

# Add only files the project does not know yet.
proc add_missing {fileset files} {
    set missing {}
    foreach f $files {
        if {[llength [get_files -quiet -of_objects [get_filesets $fileset] $f]] == 0} {
            lappend missing $f
        }
    }
    if {[llength $missing] > 0} {
        add_files -norecurse -fileset $fileset $missing
    }
    return [llength $missing]
}

if {[file exists $prj_file]} {
    puts "INFO: project exists, refreshing source lists: $prj_file"
    if {[llength [get_projects -quiet]] == 0} {
        open_project $prj_file
    }
} else {
    puts "INFO: creating project in $prj_dir"
    create_project $PRJ_NAME $prj_dir -part $FPGA_PART
    set_property target_language Verilog [current_project]
}

set n_rtl [add_missing sources_1 [glob_recursive [file join $repo_root rtl] *.v]]
set n_ip  [add_missing sources_1 [glob_recursive [file join $repo_root ip]  *.xci]]
set n_xdc [add_missing constrs_1 [glob -nocomplain -directory [file join $repo_root constr] *.xdc]]
set n_sim [add_missing sim_1     [glob_recursive [file join $repo_root sim] *.v]]

# Remove project entries whose files no longer exist (deleted upstream).
set n_removed 0
foreach f [get_files -quiet] {
    if {![file exists $f]} {
        remove_files $f
        incr n_removed
    }
}

# IP cores (.xci only in git): generate their output products locally.
set xci_objs [get_files -quiet *.xci]
if {[llength $xci_objs] > 0} {
    generate_target all $xci_objs
}

set_property top $TOP_MODULE [get_filesets sources_1]
if {[llength [get_files -quiet -of_objects [get_filesets sim_1] *${SIM_TOP}*]] > 0} {
    set_property top $SIM_TOP [get_filesets sim_1]
}
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: added rtl=$n_rtl ip=$n_ip xdc=$n_xdc sim=$n_sim, removed=$n_removed"
puts "INFO: done. Top = $TOP_MODULE, part = $FPGA_PART"
