set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6E22C8

set_location_assignment PIN_24  -to CLK
set_location_assignment PIN_88  -to nRST

set_location_assignment PIN_1   -to LEDS[0]
set_location_assignment PIN_2   -to LEDS[1]
set_location_assignment PIN_3   -to LEDS[2]
set_location_assignment PIN_7   -to LEDS[3]
set_location_assignment PIN_11  -to LEDS[4]

set_location_assignment PIN_114 -to BUTTONS[0]
set_location_assignment PIN_89  -to BUTTONS[1]
set_location_assignment PIN_80  -to BUTTONS[2]
set_location_assignment PIN_73  -to BUTTONS[3]

set_location_assignment PIN_53 -to ETH_TXD[1]
set_location_assignment PIN_49 -to ETH_TXEN
set_location_assignment PIN_50 -to ETH_TXD[0]
set_location_assignment PIN_51 -to ETH_RXD[0]
set_location_assignment PIN_52 -to ETH_RXD[1]
set_location_assignment PIN_46 -to ETH_REF_CLK
set_location_assignment PIN_54 -to ETH_CRSDV
set_location_assignment PIN_55 -to ETH_MDIO
set_location_assignment PIN_58 -to ETH_MDC

set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to CLK
set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to nRST
set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to LEDS[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to BUTTONS[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to ETH_*

set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"

set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
