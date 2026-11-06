# Recreates the Vivado project (FPGA synthesis + xsim UVM simulation) from the
# repo sources, so no generated Vivado files need to be committed.
#
# From the repo root:
#   vivado -mode batch -source scripts/vivado/create_project.tcl
#
# The project is written to build/vivado/MiniSoC.xpr (git-ignored).

set repo     [file normalize [file join [file dirname [info script]] .. ..]]
set proj_dir [file join $repo build vivado]
set part     xczu7ev-ffvc1156-2-e

# Read a filelist: one repo-relative path per line, '#' comments allowed.
proc read_filelist {repo f} {
    set files {}
    set fh [open [file join $repo $f] r]
    foreach line [split [read $fh] "\n"] {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} continue
        lappend files [file join $repo $line]
    }
    close $fh
    return $files
}

create_project MiniSoC $proj_dir -part $part -force
set_property target_language Verilog [current_project]
# Compile everything in filelist order. Automatic hierarchy-based ordering
# drops tb_binds.sv (bind statements aren't reachable from tb_top), which
# breaks the UVM virtual-interface lookups.
set_property source_mgmt_mode None [current_project]

# ---------------- Design sources ----------------
set inc_dir [file join $repo rtl include]
add_files -fileset sources_1 [file join $inc_dir Def.v]
set_property file_type {Verilog Header} [get_files Def.v]
add_files -fileset sources_1 [read_filelist $repo rtl/rtl.f]
add_files -fileset sources_1 [file join $repo fpga rtl rv32i_core_synth_top.v]
set_property include_dirs   $inc_dir   [get_filesets sources_1]
set_property verilog_define SYNTHESIS  [get_filesets sources_1]
set_property top            rv32i_soc  [get_filesets sources_1]

# ---------------- Constraints ----------------
add_files -fileset constrs_1 [file join $repo fpga constraints rv32i_soc.xdc]

# ---------------- Simulation ----------------
set sim [get_filesets sim_1]
add_files -fileset sim_1 [read_filelist $repo tb/uvm/uvm.f]
add_files -fileset sim_1 [glob [file join $repo tb directed *.v]]
# Program images get copied into the xsim run directory, where
# instruction_memory.v's +PROGRAM= plusarg looks for them.
add_files -fileset sim_1 [glob [file join $repo sw programs *.hex]]
set_property include_dirs $inc_dir $sim
set_property top     tb_top          $sim
set_property top_lib xil_defaultlib  $sim
set_property -name xsim.elaborate.xelab.more_options -value {-L uvm} -objects $sim
set_property -name xsim.simulate.runtime             -value {all}    -objects $sim
set_property -name xsim.simulate.xsim.more_options \
    -value {-testplusarg UVM_TESTNAME=random_program_test -testplusarg PROGRAM=program_random.hex} \
    -objects $sim

puts "Created [file join $proj_dir MiniSoC.xpr]"
