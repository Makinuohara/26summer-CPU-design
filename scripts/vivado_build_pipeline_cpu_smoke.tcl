create_project pipeline_cpu_smoke_nexys4ddr ./vivado_pipeline_cpu_smoke -part xc7a100tcsg324-1 -force
set fp [open ./scripts/filelist_pipeline_fpga_smoke.f r]
set file_data [read $fp]
close $fp
foreach src_file [split $file_data "\n"] {
    set src_file [string trim $src_file]
    if {$src_file ne ""} {
        add_files -fileset sources_1 $src_file
    }
}
add_files -fileset constrs_1 ./constraints/nexys4ddr_minimal.xdc
set_property top fpga_pipeline_cpu_smoke_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
file mkdir ./build/bitstreams
file copy -force ./vivado_pipeline_cpu_smoke/pipeline_cpu_smoke_nexys4ddr.runs/impl_1/fpga_pipeline_cpu_smoke_top.bit ./build/bitstreams/fpga_pipeline_cpu_smoke_top.bit
