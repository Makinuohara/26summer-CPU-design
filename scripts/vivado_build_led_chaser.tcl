create_project led_chaser_nexys4ddr ./vivado_led_chaser -part xc7a100tcsg324-1 -force
add_files ./examples/led_chaser/led_chaser_top.v
add_files -fileset constrs_1 ./constraints/nexys4ddr_led_chaser.xdc
set_property top led_chaser_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
file mkdir ./build/bitstreams
file copy -force ./vivado_led_chaser/led_chaser_nexys4ddr.runs/impl_1/led_chaser_top.bit ./build/bitstreams/led_chaser_top.bit
