`default_nettype none
module hdmi_instrument_top(
    input wire clk,output wire [5:0] led_n,inout wire i2c_scl,i2c_sda,
    input wire enc_a,enc_b,enc_sw,output wire uart_tx_o,input wire uart_rx_i,
    output wire pa_en,i2s_din,i2s_ws,i2s_bclk,
    output wire tmds_clk_p,tmds_clk_n,
    output wire [2:0] tmds_data_p,tmds_data_n
);
    wire [23:0] keys,v_keys;
    wire [2:0] timbre,v_timbre;
    wire [4:0] voices,v_voices;
    wire [8:0] volume,v_volume;
    wire [1:0] octave,v_octave;
    wire [7:0] flags,v_flags;
    wire [7:0] bpm,v_bpm,song_status,v_song_status,usb_diag,v_usb_diag;wire beat,v_beat;
    wire signed [15:0] pcm;
    wire sample_tick;
    control_top u_instrument(
        .clk(clk),.led_n(led_n),.i2c_scl(i2c_scl),.i2c_sda(i2c_sda),
        .enc_a(enc_a),.enc_b(enc_b),.enc_sw(enc_sw),
        .uart_tx_o(uart_tx_o),.uart_rx_i(uart_rx_i),
        .pa_en(pa_en),.i2s_din(i2s_din),.i2s_ws(i2s_ws),.i2s_bclk(i2s_bclk),
        .view_keys(keys),.view_timbre(timbre),.view_voices(voices),
        .view_volume(volume),.view_octave(octave),.view_flags(flags),.view_bpm(bpm),.view_beat(beat),.view_song_status(song_status),.view_usb_diag(usb_diag),
        .view_pcm(pcm),.view_sample_tick(sample_tick));
    wire clk126,clk25,pll_locked;
    video_clocks u_clocks(.clk27(clk),.clk126(clk126),.clk25(clk25),.locked(pll_locked));
    reg [3:0] reset_sync=4'hf;
    always @(posedge clk25 or negedge pll_locked)
        if(!pll_locked)reset_sync<=4'hf;
        else reset_sync<={reset_sync[2:0],1'b0};
    wire video_reset=reset_sync[3];
    wire [10:0] x;
    wire [9:0] y;
    wire de,hs,vs,frame_blank;
    video_timing u_timing(.clk(clk25),.reset(video_reset),.x(x),.y(y),
        .active(de),.hs(hs),.vs(vs),.frame_blank(frame_blank));
    wire [7:0] peak;
    video_snapshot u_snapshot(.sys_clk(clk),.pix_clk(clk25),
        .sys_reset(!pll_locked),.pix_reset(video_reset),.frame_blank(frame_blank),
        .keys(keys),.timbre(timbre),.voices(voices),.volume(volume),
        .octave(octave),.flags(flags),.bpm(bpm),.beat(beat),.song_status(song_status),.usb_diag(usb_diag),.pcm(pcm),.sample_tick(sample_tick),
        .v_keys(v_keys),.v_timbre(v_timbre),.v_voices(v_voices),
        .v_volume(v_volume),.v_octave(v_octave),.v_flags(v_flags),.v_bpm(v_bpm),.v_beat(v_beat),.v_song_status(v_song_status),.v_usb_diag(v_usb_diag),.v_peak(peak));
    wire signed [7:0] waveform;
    video_waveform u_waveform(.sys_clk(clk),.pix_clk(clk25),
        .sys_reset(!pll_locked),.pix_reset(video_reset),.frame_blank(frame_blank),
        .sample_tick(sample_tick),.pcm(pcm),.video_x(x),.sample(waveform));
    wire [23:0] rgb;
    studio_scene u_scene(.clk(clk25),.reset(video_reset),.frame_blank(frame_blank),
        .video_x(x),.video_y(y),.keys(v_keys),.timbre(v_timbre),
        .voices(v_voices),.volume(v_volume),.octave(v_octave),
        .flags(v_flags),.bpm(v_bpm),.beat(v_beat),.song_status(v_song_status),.usb_diag(v_usb_diag),.peak(peak),.waveform(waveform),.rgb(rgb));
    reg [2:0] de_pipe=0,hs_pipe=0,vs_pipe=0;
    always @(posedge clk25)begin
        de_pipe<={de_pipe[1:0],de};
        hs_pipe<={hs_pipe[1:0],hs};
        vs_pipe<={vs_pipe[1:0],vs};
    end
    video_hdmi_tx u_tx(.pix_clk(clk25),.serial_clk(clk126),.reset(video_reset),
        .de(de_pipe[2]),.hs(hs_pipe[2]),.vs(vs_pipe[2]),.rgb(rgb),
        .tmds_clk_p(tmds_clk_p),.tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p),.tmds_data_n(tmds_data_n));
endmodule
`default_nettype wire
