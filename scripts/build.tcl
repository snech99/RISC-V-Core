# =============================================================================
# build.tcl  --  synthesis + implementation + bitstream, headless.
# Prerequisite: the project must exist (run create_project.tcl first).
#
# Run:
#   vivado -mode batch -source scripts/create_project.tcl -source scripts/build.tcl
# or in the GUI Tcl console after create_project.tcl:
#   source scripts/build.tcl
# =============================================================================

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# copy the bitstream to repo-root/dist (in .gitignore -> build artifact)
set origin_dir [file normalize [file join [file dirname [info script]] ..]]
set bit [glob -nocomplain [file join [get_property DIRECTORY [get_runs impl_1]] *_wrapper.bit]]
if {[llength $bit] > 0} {
    file mkdir [file join $origin_dir dist]
    file copy -force [lindex $bit 0] [file join $origin_dir dist]
    puts "Bitstream copied to: [file join $origin_dir dist]"
}

# short timing report
open_run impl_1
report_timing_summary -max_paths 5 -file [file join $origin_dir dist timing_summary.rpt]
puts "Done. Timing report: dist/timing_summary.rpt"