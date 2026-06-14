create_clock -name main_clk -period 20.000 [get_ports CLK]

derive_pll_clocks
derive_clock_uncertainty