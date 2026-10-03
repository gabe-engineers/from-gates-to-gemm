# Program the connected Basys 3 with a bitstream built for GEMM_VARIANT
# (scalar, SIMD, or SIMT matrix multiplication).
# Find the expected Artix-7 through Vivado's hardware manager, select the
# variant's .bit file, and load it into the FPGA configuration memory.
set repo [file normalize [file join [file dirname [info script]] ../..]]
set variant $::env(GEMM_VARIANT)
if {$variant ni {scalar simd simt}} {
    error "GEMM_VARIANT must be scalar, simd, or simt"
}
set bitstream [file join $repo build fpga basys3 $variant gemm_${variant}.bit]
if {![file exists $bitstream]} {
    error "Missing $bitstream; build this variant first"
}

open_hw_manager
connect_hw_server
open_hw_target
set devices [get_hw_devices]
if {[llength $devices] != 1} {
    error "Expected one FPGA, found [llength $devices]: $devices"
}
set device [lindex $devices 0]
if {![string match *xc7a35t* $device]} {
    error "Expected Basys 3 xc7a35t, found $device"
}
current_hw_device $device
refresh_hw_device -update_hw_probes false $device
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
puts "BASYS3_PROGRAMMED=$variant"
close_hw_manager
