create_project system_acceptance_nexys4ddr ./vivado_system_acceptance -part xc7a100tcsg324-1 -force
file copy -force ./sim/system_acceptance_demo.hex ./vivado_system_acceptance/system_acceptance_demo.hex

set fp [open ./scripts/filelist_acceptance.f r]
set file_data [read $fp]
close $fp
foreach src_file [split $file_data "\n"] {
    set src_file [string trim $src_file]
    if {$src_file ne ""} {
        add_files -fileset sources_1 $src_file
    }
}
add_files -fileset sources_1 -norecurse ./sim/system_acceptance_demo.hex
set_property file_type {Memory Initialization Files} [get_files system_acceptance_demo.hex]
add_files -fileset constrs_1 ./constraints/nexys4ddr_minimal.xdc
add_files -fileset constrs_1 ./constraints/acceptance_cpu_timing.xdc
set_property top fpga_acceptance_top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

file mkdir ./build/bitstreams
file copy -force ./vivado_system_acceptance/system_acceptance_nexys4ddr.runs/impl_1/fpga_acceptance_top.bit ./build/bitstreams/system_acceptance_demo.bit
open_run impl_1
report_timing_summary -delay_type max -max_paths 10 -file ./build/bitstreams/system_acceptance_timing.rpt
report_utilization -file ./build/bitstreams/system_acceptance_utilization.rpt
