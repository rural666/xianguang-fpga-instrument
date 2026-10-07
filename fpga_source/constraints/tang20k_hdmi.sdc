create_clock -name sys_clk -period 37.037 [get_ports {clk}]
create_clock -name pixel_clk -period 39.683 [get_pins {u_clocks/u_clkdiv/CLKOUT}]
set_clock_groups -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks {pixel_clk}]
