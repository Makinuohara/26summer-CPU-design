open_hw
connect_hw_server

set targets [get_hw_targets]
if {[llength $targets] == 0} {
    puts "ERROR: no hardware targets found"
    exit 1
}

open_hw_target [lindex $targets 0]

set devices [get_hw_devices]
if {[llength $devices] == 0} {
    puts "ERROR: no hardware devices found"
    exit 1
}

set dev [lindex $devices 0]
current_hw_device $dev
refresh_hw_device $dev

set_property PROGRAM.FILE {D:/26summer-CPU-design/build/bitstreams/led_chaser_top.bit} $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "PROGRAM_OK: led_chaser_top.bit programmed"
