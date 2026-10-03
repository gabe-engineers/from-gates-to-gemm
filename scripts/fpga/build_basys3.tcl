set repo [file normalize [file join [file dirname [info script]] ../..]]
set variant $::env(GEMM_VARIANT)
if {$variant ni {scalar simd simt}} {
    error "GEMM_VARIANT must be scalar, simd, or simt"
}
set image [file join $repo build fpga gemm_${variant}.mem]
if {![file exists $image]} {
    error "Missing $image; run just fpga-images first"
}
set output [file join $repo build fpga basys3 $variant]
set image_prefix [file join $repo build fpga gemm_${variant}]
file mkdir $output

set filelist [open [file join $repo rtl filelists chip.f] r]
set sources {}
foreach line [split [read $filelist] "\n"] {
    set source [string trim $line]
    if {$source ne "" && ![string match "#*" $source]} {
        lappend sources [file join $repo $source]
    }
}
close $filelist
lappend sources [file join $repo rtl top uart_tx_byte.sv]
lappend sources [file join $repo rtl top basys3_gemm.sv]

set_property include_dirs [list [file join $repo rtl include]] [current_fileset]
read_verilog -sv {*}$sources
synth_design -top basys3_gemm -part xc7a35tcpg236-1 \
    -generic "RAM_INIT_PREFIX=$image_prefix"
read_xdc [file join $repo scripts fpga basys3_gemm.xdc]
report_utilization -file [file join $output utilization_synth.rpt]

opt_design
place_design
route_design
report_utilization -file [file join $output utilization.rpt]
report_timing_summary -delay_type max -max_paths 10 \
    -file [file join $output timing.rpt]
set worst_setup [get_property SLACK [lindex [get_timing_paths -setup -max_paths 1] 0]]
if {$worst_setup < 0} {
    error "Routed setup timing failed for $variant: slack $worst_setup ns"
}
write_bitstream -force [file join $output gemm_${variant}.bit]
puts "BASYS3_BITSTREAM=[file join $output gemm_${variant}.bit]"
