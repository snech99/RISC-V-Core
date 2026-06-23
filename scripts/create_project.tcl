# =============================================================================
# create_project.tcl
# Regenerates the complete Vivado project from the sources in the repo.
#
# Run (headless):
#   vivado -mode batch -source scripts/create_project.tcl
# or in the Vivado Tcl console (GUI):
#   cd <repo-root>; source scripts/create_project.tcl
# =============================================================================

set proj_name  "rv32im_basys3"
set part       "xc7a35tcpg236-1"        ;# Basys 3 (Artix-7 XC7A35T)

# repo root = one directory above this script (scripts/..)
set origin_dir [file normalize [file join [file dirname [info script]] ..]]

# the generated project lives under vivado/ (excluded by .gitignore)
set proj_dir [file join $origin_dir vivado]

# remove an old generated project
if {[file exists $proj_dir]} { file delete -force $proj_dir }
file mkdir $proj_dir

create_project $proj_name $proj_dir -part $part -force

# -----------------------------------------------------------------------------
# 1) (optional) Register a custom IP repository -- ONLY if you packaged IP.
#    Your core and custom_bram are referenced as RTL MODULES in the block
#    design (BD warning 41-2925), not as packaged IP, so this is normally
#    skipped. The guard avoids an error when ip/ is empty.
# -----------------------------------------------------------------------------
set ip_dir [file join $origin_dir ip]
if {[file isdirectory $ip_dir] && [llength [glob -nocomplain [file join $ip_dir *]]] > 0} {
    set_property ip_repo_paths $ip_dir [current_project]
    update_ip_catalog
}

# -----------------------------------------------------------------------------
# 2) Add RTL sources
#    (only needed for modules NOT already inside packaged IP)
# -----------------------------------------------------------------------------
set rtl_files [glob -nocomplain \
    [file join $origin_dir rtl core *.v] \
    [file join $origin_dir rtl mem  *.v]]
if {[llength $rtl_files] > 0} {
    add_files -fileset sources_1 $rtl_files
}

# -----------------------------------------------------------------------------
# 3) Memory init for the BRAM
#    IMPORTANT: custom_bram does $readmemh("test_program_code_hex.mem", ...).
#    Relative $readmemh paths resolve relative to the RUN directory, so the
#    .mem must be known to the project as a source, otherwise the BRAM is empty.
# -----------------------------------------------------------------------------
set mem_file [file join $origin_dir mem test_program_code_hex.mem]
if {[file exists $mem_file]} {
    add_files -fileset sources_1 $mem_file
}

# -----------------------------------------------------------------------------
# 4) Constraints
# -----------------------------------------------------------------------------
add_files -fileset constrs_1 [file join $origin_dir constraints basys3.xdc]

# -----------------------------------------------------------------------------
# 5) Recreate the block design from Tcl
#    The RTL modules (rv32im_axi_top, custom_bram) referenced by the BD were
#    already added in step 2 -- they MUST exist before sourcing this, otherwise
#    Vivado cannot resolve the module references (BD warning 41-2925).
#    Export beforehand with:  write_bd_tcl -force bd/system_bd.tcl
# -----------------------------------------------------------------------------
source [file join $origin_dir bd system_bd.tcl]
regenerate_bd_layout
save_bd_design

# -----------------------------------------------------------------------------
# 6) Generate the HDL wrapper and set it as top
#    CAUTION: get_files *.bd also matches the nested sub-BDs that live INSIDE
#    generated IP (e.g. the SmartConnect's internal bd_xxxx.bd). Feeding those
#    to make_wrapper fails (BD 41-1031). We therefore take the real top-level
#    block design name from current_bd_design and pick only that .bd file,
#    explicitly skipping anything under an /ip/ path.
# -----------------------------------------------------------------------------
set top_bd_name [get_property NAME [current_bd_design]]

set bd_file ""
foreach f [get_files -quiet ${top_bd_name}.bd] {
    if {[string first "/ip/" $f] == -1} { set bd_file $f; break }
}
if {$bd_file eq ""} {
    error "Could not locate the top-level .bd for design '$top_bd_name'"
}

make_wrapper -files $bd_file -top
set wrapper [glob -nocomplain \
    [file join $proj_dir ${proj_name}.gen  sources_1 bd $top_bd_name hdl ${top_bd_name}_wrapper.v] \
    [file join $proj_dir ${proj_name}.srcs sources_1 bd $top_bd_name hdl ${top_bd_name}_wrapper.v]]
if {[llength $wrapper] > 0} {
    add_files -norecurse $wrapper
}
set_property top ${top_bd_name}_wrapper [current_fileset]

update_compile_order -fileset sources_1

puts "============================================================"
puts " Project regenerated at: $proj_dir"
puts " Next step:  source scripts/build.tcl"
puts "============================================================"
