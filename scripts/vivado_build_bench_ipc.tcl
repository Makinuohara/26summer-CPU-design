create_project bench_ipc_nexys4ddr ./vivado_bench_ipc -part xc7a100tcsg324-1 -force
file copy -force ./sim/bench_ipc.hex ./vivado_bench_ipc/bench_ipc.hex

set fp [open ./scripts/filelist_acceptance.f r]
set file_data [read $fp]
close $fp
foreach src_file [split $file_data "\n"] {
    set src_file [string trim $src_file]
    if {$src_file ne ""} {
        add_files -fileset sources_1 $src_file
    }
}
add_files -fileset sources_1 -norecurse ./sim/bench_ipc.hex
set_property file_type {Memory Initialization Files} [get_files bench_ipc.hex]
add_files -fileset constrs_1 ./constraints/nexys4ddr_minimal.xdc
add_files -fileset constrs_1 ./constraints/acceptance_cpu_timing.xdc
set_property top fpga_acceptance_top [current_fileset]
set_property generic {IMEM_INIT_FILE=bench_ipc.hex} [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

file mkdir ./build/bitstreams
file copy -force ./vivado_bench_ipc/bench_ipc_nexys4ddr.runs/impl_1/fpga_acceptance_top.bit ./build/bitstreams/bench_ipc_demo.bit
open_run impl_1
report_timing_summary -delay_type max -max_paths 10 -file ./build/bitstreams/bench_ipc_timing.rpt
report_utilization -file ./build/bitstreams/bench_ipc_utilization.rpt
