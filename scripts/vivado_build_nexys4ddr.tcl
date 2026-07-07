create_project rv32i_cpu_nexys4ddr ./vivado_nexys4ddr -part xc7a100tcsg324-1 -force
add_files [glob ./src/*.v]
add_files -fileset constrs_1 ./constraints/nexys4ddr_minimal.xdc
set_property top fpga_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
file mkdir ./build/bitstreams
file copy -force ./vivado_nexys4ddr/rv32i_cpu_nexys4ddr.runs/impl_1/fpga_top.bit ./build/bitstreams/fpga_top.bit
