create_project sim_isr_test ./vivado_sim_isr -part xc7a100tcsg324-1 -force
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
add_files -fileset sim_1 ./sim/tb_isr_test.v
set_property include_dirs ./src/memory [get_filesets sim_1]
set_property top tb_isr_test [get_filesets sim_1]
update_compile_order -fileset sim_1
set_property -name {xsim.simulate.runtime} -value {100000ns} -objects [get_filesets sim_1]
launch_simulation
run all
close_sim
