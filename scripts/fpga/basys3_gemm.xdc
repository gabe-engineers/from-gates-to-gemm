set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk100]
create_clock -period 10.000 -name clk100 [get_ports clk100]

set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btn_reset]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports led_halted]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports uart_txd]

create_generated_clock -name core_clk -source [get_ports clk100] -divide_by 4 \
    [get_pins core_clock_buffer/O]
