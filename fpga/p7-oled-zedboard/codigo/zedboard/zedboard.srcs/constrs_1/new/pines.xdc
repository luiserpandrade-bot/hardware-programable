# Clock
set_property PACKAGE_PIN Y9 [get_ports clk]
create_clock -period 100.000 -name CLK -waveform {0.000 50.000} [get_ports clk]

# OLED display
set_property PACKAGE_PIN U10 [get_ports oled_dc]
set_property PACKAGE_PIN U9 [get_ports oled_res]
set_property PACKAGE_PIN AB12 [get_ports oled_sclk]
set_property PACKAGE_PIN AA12 [get_ports oled_sdin]
set_property PACKAGE_PIN U11 [get_ports oled_vbat]
set_property PACKAGE_PIN U12 [get_ports oled_vdd]

# Reset
set_property PACKAGE_PIN P16 [get_ports rst]

# Voltage settings
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 34]]
set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 13]]

set_property IOSTANDARD LVCMOS33 [get_ports {a[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {a[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {a[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[0]}]
set_property PACKAGE_PIN F22 [get_ports {a[0]}]
set_property PACKAGE_PIN G22 [get_ports {a[1]}]
set_property PACKAGE_PIN H22 [get_ports {a[2]}]
set_property PACKAGE_PIN F21 [get_ports {b[0]}]
set_property PACKAGE_PIN H19 [get_ports {b[1]}]
set_property PACKAGE_PIN H18 [get_ports {b[2]}]
