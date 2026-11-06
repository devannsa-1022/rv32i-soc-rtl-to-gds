# Runs one UVM test in xsim (batch mode), creating the project first if needed.
#
# From the repo root:
#   vivado -mode batch -source scripts/vivado/run_uvm.tcl -tclargs [test] [program.hex]
#
# Defaults: random_program_test, program_random.hex.
# Log: build/vivado/MiniSoC.sim/sim_1/behav/xsim/simulate.log

set repo [file normalize [file join [file dirname [info script]] .. ..]]
set xpr  [file join $repo build vivado MiniSoC.xpr]

set test    [expr {[llength $argv] > 0 ? [lindex $argv 0] : "random_program_test"}]
set program [expr {[llength $argv] > 1 ? [lindex $argv 1] : "program_random.hex"}]

if {![file exists $xpr]} {
    source [file join $repo scripts vivado create_project.tcl]
} else {
    open_project $xpr
}

set_property -name xsim.simulate.xsim.more_options \
    -value "-testplusarg UVM_TESTNAME=$test -testplusarg PROGRAM=$program" \
    -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
close_sim
close_project
