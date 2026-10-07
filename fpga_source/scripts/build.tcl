set script_dir [file dirname [info script]]
cd [file dirname $script_dir]
foreach memory {rtl/sine2048.hex rtl/ima_steps.hex assets/font8x16.hex assets/scene_text.hex assets/ui_top_640x210.hex assets/ui_prompt_304x24.hex assets/ui_digits_24x48.hex} {
    if {![file exists $memory] || [file size $memory] == 0} {
        error "Required audio ROM missing: $memory"
    }
}
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
foreach src {uart_tx uart_rx i2s_tx synth_core metronome ima_encoder adpcm6_encoder audio_uart_stream audio_decimate room_reverb i2c_reg_xfer mpu6050_reader encoder_control tilt_expression speaker_conditioner speaker_volume control_report control_top video_timing video_snapshot video_waveform tmds_encoder video_clocks video_hdmi_tx studio_scene hdmi_instrument_top} {
    add_file rtl/${src}.v
}
add_file constraints/tang20k_hdmi.cst
add_file constraints/tang20k_hdmi.sdc
set_option -top_module hdmi_instrument_top
set_option -output_base_name control
set_option -verilog_std v2001
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
run all
