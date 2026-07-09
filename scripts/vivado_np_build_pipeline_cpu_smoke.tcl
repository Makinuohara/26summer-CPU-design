set part_name xc7a100tcsg324-1
set top_name fpga_pipeline_cpu_smoke_top
set_param general.maxThreads 1

set fp [open ./scripts/filelist_pipeline_fpga_smoke.f r]
set file_data [read $fp]
close $fp
foreach src_file [split $file_data "\n"] {
    set src_file [string trim $src_file]
    if {$src_file ne ""} {
        read_verilog -sv $src_file
    }
}

read_xdc ./constraints/nexys4ddr_minimal.xdc
synth_design -top $top_name -part $part_name
opt_design
place_design
route_design
file mkdir ./build/bitstreams
write_bitstream -force ./build/bitstreams/fpga_pipeline_cpu_smoke_top.bit
