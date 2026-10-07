`default_nettype none
module control_top #(
    parameter integer WATCHDOG_CYCLES=54000000,AB_FILTER=2700,SW_FILTER=270000,
    parameter integer SENSOR_BOOT=2700000,SENSOR_RETRY=27000000,REPORT_CYCLES=5400000
)(
    input wire clk,output wire [5:0] led_n,inout wire i2c_scl,i2c_sda,
    input wire enc_a,enc_b,enc_sw,output wire uart_tx_o,input wire uart_rx_i,
    output wire pa_en,i2s_din,i2s_ws,i2s_bclk,
    output wire [23:0] view_keys,output wire [2:0] view_timbre,
    output wire [4:0] view_voices,output wire [8:0] view_volume,
    output wire [1:0] view_octave,output wire [7:0] view_flags,
    output wire [7:0] view_bpm,output wire view_beat,
    output wire [7:0] view_song_status,
    output wire [7:0] view_usb_diag,
    output wire signed [15:0] view_pcm,output wire view_sample_tick
);
    reg [15:0] por=0;wire rst=!(&por);
    always @(posedge clk)if(rst)por<=por+1'b1;
    wire rx_valid,rx_error;wire [7:0] rx_data;
    uart_rx #(.BAUD(230400)) u_rx(.clk(clk),.rst(rst),.rx(uart_rx_i),.valid(rx_valid),.data(rx_data),.framing_error(rx_error));
    wire sample_tick,active,overrun,stream_overflow;wire signed [15:0] pcm,pcm_raw,pcm_room,pcm_expression,pcm_voiced,pcm_click,pcm_mix;
    wire speaker_limit_fault;
    wire [4:0] voice_count;
    wire encoder_up,encoder_down,encoder_press;wire signed [31:0] encoder_position;
    wire [15:0] encoder_presses;wire [2:0] encoder_pins;
    encoder_control #(.AB_FILTER(AB_FILTER),.SW_FILTER(SW_FILTER)) u_encoder(
        .clk(clk),.rst(rst),.enc_a(enc_a),.enc_b(enc_b),.enc_sw(enc_sw),.step_up(encoder_up),.step_down(encoder_down),
        .press(encoder_press),.position(encoder_position),.presses(encoder_presses),.stable_pins(encoder_pins));
    wire mpu_online,mpu_valid;wire [2:0] mpu_status;wire [6:0] mpu_address;wire [7:0] mpu_id;
    wire [31:0] mpu_samples;wire [15:0] mpu_errors;wire signed [15:0] ax,ay,az,tp,gx,gy,gz;
    mpu6050_reader #(.BOOT_CYCLES(SENSOR_BOOT),.RETRY_CYCLES(SENSOR_RETRY)) u_mpu(
        .clk(clk),.rst(rst),.scl(i2c_scl),.sda(i2c_sda),.online(mpu_online),.sample_valid(mpu_valid),
        .status(mpu_status),.address(mpu_address),.whoami(mpu_id),.samples(mpu_samples),.errors(mpu_errors),
        .ax(ax),.ay(ay),.az(az),.temperature(tp),.gx(gx),.gy(gy),.gz(gz));
    reg expression_enabled,expression_calibrate,lock_volume,unlock_volume,reset_volume;
    wire expression_calibrated,expression_calibrating,expression_locked;wire [8:0] expression_gain;
    tilt_expression u_expression(.clk(clk),.rst(rst),.sample_tick(sample_tick),.sample_valid(mpu_valid),
        .enabled(expression_enabled),.online(mpu_online),.calibrate(expression_calibrate),
        .lock_volume(lock_volume),.unlock_volume(unlock_volume),.reset_volume(reset_volume),
        .ax(ax),.ay(ay),.az(az),.pcm_in(pcm_voiced),.pcm_out(pcm_expression),.gain(expression_gain),
        .calibrated(expression_calibrated),.calibrating(expression_calibrating),.locked(expression_locked));
    reg [8:0] speaker_volume;wire [8:0] applied_volume;reg volume_packet;
    wire signed [16:0] metronome_sum=$signed(pcm_room)+$signed(pcm_click);
    assign pcm_mix=metronome_sum>32767 ? 16'sd32767 : metronome_sum< -32768 ? -16'sd32768 : metronome_sum[15:0];
    speaker_conditioner u_speaker_conditioner(.clk(clk),.rst(rst),.sample_tick(sample_tick),.pcm_in(pcm_mix),.voices(voice_count),.pcm_out(pcm_voiced),.limit_fault(speaker_limit_fault));
    speaker_volume u_speaker_volume(.clk(clk),.rst(rst),.sample_tick(sample_tick),.target(speaker_volume),.pcm_in(pcm_expression),.pcm_out(pcm),.applied(applied_volume));
    reg [23:0] pc_keys;reg [7:0] metronome_bpm;wire metronome_beat;
    reg [2:0] timbre;reg [1:0] octave;
    metronome u_metronome(.clk(clk),.rst(rst),.sample_tick(sample_tick),.bpm(metronome_bpm),.click(pcm_click),.flash(metronome_beat));
    reg sustain,room_enabled,vibrato_enabled,demo,stream_enabled;
    reg [18:0] demo_count;reg [26:0] watchdog,heartbeat;reg [15:0] command_count;reg [7:0] last_rx;
    reg [2:0] key_command_state;reg [11:0] pending_keys;reg [3:0] pending_check;
    reg [2:0] packet_kind; // 0 low keys, 1 upper keys, 2 volume, 3 BPM, 4 song, 5 USB
    reg [7:0] song_status;
    reg [7:0] usb_diag;
    reg [19:0] key_command_timeout;
    wire [7:0] lower=rx_data|8'h20;reg [3:0] note_index;
    wire is_hex=(rx_data>="0" && rx_data<="9") || (rx_data>="A" && rx_data<="F");
    wire [3:0] hex_value=rx_data<="9" ? rx_data-8'h30 : rx_data-8'h37;
    always @*begin case(lower)
        "a":note_index=0;"w":note_index=1;"s":note_index=2;"e":note_index=3;"d":note_index=4;"f":note_index=5;
        "t":note_index=6;"g":note_index=7;"y":note_index=8;"h":note_index=9;"u":note_index=10;"j":note_index=11;
        default:note_index=15;
    endcase end
    reg [11:0] demo_keys;
    always @*begin
        demo_keys=0;
        if(demo)begin
            if(demo_count>=4688 && demo_count<18750)demo_keys=12'h200;
            else if(demo_count>=28125 && demo_count<42188)demo_keys=12'h010;
            else if(demo_count>=56250 && demo_count<93750)demo_keys=12'h091;
        end
    end
    wire [15:0] abs_gx=gx[15]?-gx:gx,abs_gy=gy[15]?-gy:gy,abs_gz=gz[15]?-gz:gz;
    wire [15:0] max_xy=abs_gx>abs_gy?abs_gx:abs_gy;
    wire [15:0] gyro_peak=max_xy>abs_gz?max_xy:abs_gz;
    wire [15:0] gyro_above=gyro_peak>512?gyro_peak-16'd512:16'd0;
    wire [6:0] gyro_target=gyro_above>4064?7'd127:gyro_above[11:5];
    reg [6:0] vibrato_depth;
    wire [8:0] gyro_filter={2'b0,vibrato_depth}+({2'b0,vibrato_depth}<<1)+{2'b0,gyro_target};
    always @(posedge clk)begin
        if(rst)vibrato_depth<=0;
        else if(!vibrato_enabled || !mpu_online)vibrato_depth<=0;
        else if(mpu_valid)vibrato_depth<=gyro_filter[8:2];
    end
    always @(posedge clk)begin
        if(rst)begin
            speaker_volume<=256;volume_packet<=0;pc_keys<=0;metronome_bpm<=0;packet_kind<=0;song_status<=0;usb_diag<=0;timbre<=0;octave<=1;sustain<=0;room_enabled<=1;vibrato_enabled<=0;demo<=0;demo_count<=0;
            watchdog<=0;heartbeat<=0;command_count<=0;last_rx<=0;stream_enabled<=0;
            expression_enabled<=0;expression_calibrate<=0;lock_volume<=0;unlock_volume<=0;reset_volume<=0;
            key_command_state<=0;pending_keys<=0;pending_check<=0;key_command_timeout<=0;
        end else begin
            heartbeat<=heartbeat+1'b1;expression_calibrate<=0;lock_volume<=0;unlock_volume<=0;reset_volume<=0;
            if(encoder_up)timbre<=timbre+1'b1;if(encoder_down)timbre<=timbre-1'b1;
            if(encoder_press)begin
                if(!expression_enabled)begin expression_enabled<=1;unlock_volume<=1;expression_calibrate<=1;end
                else if(expression_locked)unlock_volume<=1;else lock_volume<=1;
            end
            if(watchdog<WATCHDOG_CYCLES)watchdog<=watchdog+1'b1;
            else begin pc_keys<=0;stream_enabled<=0;sustain<=0;demo<=0;end
            if(key_command_state!=0)begin
                if(key_command_timeout==20'd1048575)key_command_state<=0;
                else key_command_timeout<=key_command_timeout+1'b1;
            end
            if(sample_tick && demo)begin
                if(demo_count==19'd117187)demo<=0;else demo_count<=demo_count+1'b1;
            end
            if(rx_valid)begin
                watchdog<=0;command_count<=command_count+1'b1;last_rx<=rx_data;key_command_timeout<=0;
                if(rx_data=="X")begin pc_keys<=0;demo<=0;sustain<=0;key_command_state<=0;end
                // D is also a hex digit in payloads and checksums.
                else if(rx_data=="Q" || rx_data=="H" || rx_data=="!" || rx_data=="T" || rx_data=="S" || (rx_data=="D" && key_command_state==0))begin
                    key_command_state<=1;pending_keys<=0;volume_packet<=rx_data=="!";
                    packet_kind<=rx_data=="Q" ? 0 : rx_data=="H" ? 1 : rx_data=="!" ? 2 : rx_data=="T" ? 3 : rx_data=="S" ? 4 : 5;
                end
                else if(key_command_state!=0)begin
                    if(key_command_state<=3 && is_hex)begin pending_keys<={pending_keys[7:0],hex_value};key_command_state<=key_command_state+1'b1;end
                    else if(key_command_state==4 && is_hex)begin pending_check<=hex_value;key_command_state<=5;end
                    else begin
                        if(key_command_state==5 && rx_data==";" && pending_check==(pending_keys[11:8]^pending_keys[7:4]^pending_keys[3:0]^(volume_packet?4'h5:4'ha)))begin
                            case(packet_kind)
                                0:begin pc_keys[11:0]<=pending_keys;demo<=0;end
                                1:begin pc_keys[23:12]<=pending_keys;demo<=0;end
                                2:if(pending_keys<=256)speaker_volume<=pending_keys[8:0];
                                3:if(pending_keys==0 || (pending_keys>=40 && pending_keys<=240))metronome_bpm<=pending_keys[7:0];
                                4:if(pending_keys<=255 && pending_keys[2:0]<6)song_status<=pending_keys[7:0];
                                5:if(pending_keys<=255)usb_diag<=pending_keys[7:0];
                            endcase
                        end
                        key_command_state<=0;
                    end
                end
                else if(rx_data=="b")stream_enabled<=1;
                else if(rx_data=="z")stream_enabled<=0;
                else if(rx_data=="m")begin expression_enabled<=1;unlock_volume<=1;end
                else if(rx_data=="n")begin expression_enabled<=0;reset_volume<=1;end
                else if(rx_data=="c")expression_calibrate<=1;
                else if(rx_data=="L")lock_volume<=1;
                else if(rx_data=="l")begin expression_enabled<=1;unlock_volume<=1;end
                else if(rx_data=="R")begin reset_volume<=1;speaker_volume<=256;end
                else if(rx_data=="o")sustain<=1;else if(rx_data=="O")sustain<=0;
                else if(rx_data=="r")room_enabled<=1;else if(rx_data=="x")room_enabled<=0;
                else if(rx_data=="v")vibrato_enabled<=1;else if(rx_data=="V")vibrato_enabled<=0;
                else if(rx_data=="<" && octave!=0)octave<=octave-1'b1;
                else if(rx_data==">" && octave!=2)octave<=octave+1'b1;
                else if(rx_data=="P")begin demo<=1;demo_count<=0;pc_keys<=0;sustain<=0;end
                else if(rx_data>="1" && rx_data<="8")timbre<=rx_data[2:0]-3'd1;
                else if(note_index<12)begin pc_keys[note_index]<=rx_data[5];demo<=0;end
            end
        end
    end
    synth_core #(.MASTER_SHIFT(4),.LINEAR_MIX(1)) u_synth(.clk(clk),.rst(rst),.sample_tick(sample_tick),.keys(pc_keys|{12'b0,demo_keys}),.timbre(timbre),
        .sustain(sustain),.octave(octave),.vibrato_depth(vibrato_depth),.pcm(pcm_raw),.active(active),.overrun(overrun),.voice_count(voice_count));
    room_reverb u_room(.clk(clk),.rst(rst),.sample_tick(sample_tick),.enabled(room_enabled),.dry(pcm_raw),.wet(pcm_room));
    i2s_tx u_i2s(.clk(clk),.rst(rst),.pcm(pcm),.bclk(i2s_bclk),.ws(i2s_ws),.din(i2s_din),.sample_tick(sample_tick));
    wire usb_tick;wire signed [15:0] usb_pcm;
    audio_decimate u_decimate(.clk(clk),.rst(rst),.sample_tick(sample_tick),.pcm(pcm),.tick(usb_tick),.sample(usb_pcm));
    wire audio_tx,diag_tx;
    wire [3:0] stream_voices=voice_count>15 ? 4'd15 : voice_count[3:0];
    wire [7:0] flags={expression_enabled,mpu_online,demo,timbre[1:0],active,1'b0,overrun};
    wire [15:0] meta={speaker_limit_fault,1'b1,sustain,vibrato_enabled,expression_locked,expression_calibrating,expression_calibrated,expression_gain};
    audio_uart_stream u_stream(.clk(clk),.rst(rst|!stream_enabled),.sample_tick(usb_tick),.pcm(usb_pcm),
        .flags(flags),.expression_meta(meta),.keys(pc_keys[11:0]|pc_keys[23:12]|demo_keys),.timbre(timbre),.voices(stream_voices),.octave(octave),
        .room(room_enabled),.vibrato_depth(vibrato_depth),.tx(audio_tx),.overflow(stream_overflow));
    control_report #(.REPORT_CYCLES(REPORT_CYCLES)) u_report(.clk(clk),.rst(rst),.status(mpu_status),.address(mpu_address),.whoami(mpu_id),
        .samples(mpu_samples),.errors(mpu_errors),.ax(ax),.ay(ay),.az(az),.tp(tp),.gx(gx),.gy(gy),.gz(gz),.timbre(timbre),
        .expression_enabled(expression_enabled),.gain(expression_gain),.position(encoder_position),.presses(encoder_presses),
        .rx(last_rx),.commands(command_count),.tx(diag_tx));
    assign uart_tx_o=stream_enabled?audio_tx:diag_tx;
    assign pa_en=!rst && stream_enabled && watchdog<WATCHDOG_CYCLES && applied_volume!=0;
    assign led_n={~mpu_online,~expression_locked,~timbre[1],~timbre[0],~active,~heartbeat[24]};
    assign view_keys=pc_keys|{12'b0,demo_keys};
    assign view_timbre=timbre;
    assign view_voices=voice_count;
    assign view_bpm=metronome_bpm;
    assign view_beat=metronome_beat;
    assign view_song_status=song_status;
    assign view_usb_diag=usb_diag;
    assign view_volume=speaker_volume;
    assign view_octave=octave;
    assign view_flags={demo,stream_enabled,vibrato_enabled,room_enabled,sustain,expression_locked,expression_enabled,mpu_online};
    assign view_pcm=pcm;
    assign view_sample_tick=sample_tick;
endmodule
`default_nettype wire
