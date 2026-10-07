# Run after opening control.gprj; these match the HDMI batch build.
set_option -top_module hdmi_instrument_top
set_option -output_base_name control
set_option -verilog_std v2001
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
