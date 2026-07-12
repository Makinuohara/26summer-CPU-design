create_project sim_led_test ./vivado_sim_led_test -part xc7a100tcsg324-1 -force
file copy -force ./sim/ps2_keyboard_isr.hex ./vivado_sim_led_test/ps2_keyboard_isr.hex
file copy -force ./sim/led_test.hex ./vivado_sim_led_test/led_test.hex

# Add sources from pipeline filelist
set fp [open ./scripts/filelist_pipeline.f r]
set file_data [read $fp]
close $fp
foreach src_file [split $file_data "\n"] {
    set src_file [string trim $src_file]
    if {$src_file ne ""} {
        add_files -fileset sim_1 $src_file
    }
}
add_files -fileset sim_1 ./src/memory/imem.v
add_files -fileset sim_1 ./sim/tb_led_test.v
set_property include_dirs ./src/memory [get_filesets sim_1]
set_property top tb_led_test [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {100000ns} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

launch_simulation
run all
close_sim
