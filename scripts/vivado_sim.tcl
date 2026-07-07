create_project rv32i_cpu_sim ./vivado_sim -part xc7a100tcsg324-1 -force
add_files [glob ./src/*.v]
add_files -fileset sim_1 ./sim/tb_cpu_top.v
add_files -fileset sim_1 ./sim/program.hex
set_property top tb_cpu_top [get_filesets sim_1]
launch_simulation
run 400ns
