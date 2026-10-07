`timescale 1ns/1ps
module tb_control_top;
    reg clk=0;always #5 clk=~clk;reg uart_rx_i=1;tri1 i2c_scl,i2c_sda;reg enc_a=1,enc_b=1,enc_sw=1;
    wire uart_tx_o,pa_en,i2s_din,i2s_ws,i2s_bclk;wire [5:0]led_n;
    wire [23:0] view_keys;wire [2:0] view_timbre;wire [4:0] view_voices;
    wire [8:0] view_volume;wire [1:0] view_octave;wire [7:0] view_flags;
    wire [7:0] view_bpm,view_song_status,view_usb_diag;wire view_beat;
    wire signed [15:0] view_pcm;wire view_sample_tick;
    control_top #(.WATCHDOG_CYCLES(600000),.AB_FILTER(4),.SW_FILTER(12),.SENSOR_BOOT(100),.SENSOR_RETRY(1000))dut(.*);
    wire [23:0] scene_rgb;
    studio_scene scene(.clk(clk),.reset(dut.rst),.frame_blank(1'b0),
        .video_x(11'd0),.video_y(10'd0),.keys(view_keys),.timbre(view_timbre),
        .voices(view_voices),.volume(view_volume),.octave(view_octave),
        .flags(view_flags),.peak(8'd0),.bpm(view_bpm),.beat(view_beat),
        .song_status(view_song_status),.usb_diag(view_usb_diag),
        .waveform(8'sd0),.rgb(scene_rgb));
    reg [47:0] volume_messages[0:10];
    reg [8:0] volume_gains[0:10];
    integer step_index;
    task send(input [7:0] ch);
        begin @(negedge clk);uart_rx_i=0;repeat(117)@(negedge clk);for(integer i=0;i<8;i++)begin uart_rx_i=ch[i];repeat(117)@(negedge clk);end uart_rx_i=1;repeat(117)@(negedge clk);end
    endtask
    task check_volume(input integer step);
        begin
            for(integer byte_index=0;byte_index<6;byte_index=byte_index+1)
                send(volume_messages[step][47-byte_index*8 -: 8]);
            if(view_volume!=volume_gains[step] || scene.percent!=step*10)
                $fatal(1,"Volume %0d%%: received gain %0d, display %0d",step*10,view_volume,scene.percent);
            if(dut.pc_keys!=24'h000091)$fatal(1,"Volume changed held chord");
            send("D");send("0");send("0");send("9");send("3");send(";");
            if(view_usb_diag!=9 || view_volume!=volume_gains[step])
                $fatal(1,"USB diagnostic packet disturbed volume");
        end
    endtask
    task ep(input [1:0] ab);begin @(negedge clk);{enc_a,enc_b}=ab;repeat(12)@(negedge clk);end endtask
    initial begin
        volume_messages[0]="!0005;";volume_gains[0]=0;
        volume_messages[1]="!01AE;";volume_gains[1]=26;
        volume_messages[2]="!0335;";volume_gains[2]=51;
        volume_messages[3]="!04DC;";volume_gains[3]=77;
        volume_messages[4]="!0665;";volume_gains[4]=102;
        volume_messages[5]="!080D;";volume_gains[5]=128;
        volume_messages[6]="!09A6;";volume_gains[6]=154;
        volume_messages[7]="!0B3D;";volume_gains[7]=179;
        volume_messages[8]="!0CD4;";volume_gains[8]=205;
        volume_messages[9]="!0E6D;";volume_gains[9]=230;
        volume_messages[10]="!1004;";volume_gains[10]=256;
        wait(!dut.rst);if(!dut.expression_locked||dut.expression_gain!=256)$fatal(1,"default volume lock");
        send("S");send("0");send("1");send("4");send("F");send(";");
        if(view_song_status!=8'h14)$fatal(1,"song status packet");
        send("b");send("Q");send("0");send("9");send("1");send("2");
        if(dut.pc_keys!=0)$fatal(1,"key packet must commit atomically");send(";");repeat(5000)@(negedge clk);
        if(dut.pc_keys!=12'h091 || dut.voice_count!=3)$fatal(1,"atomic chord");
        if(!pa_en || dut.speaker_volume!=256 || dut.meta[15:14]!=1)$fatal(1,"board output default");
        send("!");send("0");send("8");send("0");send("D");
        if(dut.speaker_volume!=256)$fatal(1,"partial volume packet committed");
        send(";");if(dut.speaker_volume!=128 || dut.pc_keys!=12'h091)$fatal(1,"half volume disturbed chord");
        send("!");send("1");send("0");send("1");send("5");send(";");
        if(dut.speaker_volume!=128)$fatal(1,"out of range volume accepted");
        send("!");send("0");send("0");send("0");send("4");send(";");
        if(dut.speaker_volume!=128)$fatal(1,"bad volume checksum accepted");
        send("!");send("0");send("0");send("0");send("5");send(";");
        repeat(150000)@(negedge clk);
        if(dut.applied_volume!=0 || dut.pcm!=0 || pa_en)$fatal(1,"muting must zero PCM and disable amp");
        send("R");repeat(5)@(negedge clk);if(dut.speaker_volume!=256)$fatal(1,"restore speaker volume");
        for(step_index=10;step_index>=0;step_index=step_index-1)check_volume(step_index);
        for(step_index=0;step_index<=10;step_index=step_index+1)check_volume(step_index);
        send("o");send("Q");send("0");send("0");send("0");send("A");send(";");repeat(5000)@(negedge clk);
        if(dut.pc_keys!=0 || !dut.sustain || dut.voice_count!=3)$fatal(1,"sustain integration");
        send("Q");send("F");send("F");send("F");send("0");send(";");if(dut.pc_keys!=0)$fatal(1,"bad checksum accepted");
        send("8");repeat(5)@(negedge clk);if(dut.timbre!=7)$fatal(1,"eighth timbre");
        ep(1);ep(0);ep(2);ep(3);repeat(5)@(negedge clk);if(dut.timbre!=0)$fatal(1,"encoder wrap");
        send("l");repeat(5)@(negedge clk);if(dut.expression_locked || !dut.expression_enabled)$fatal(1,"unlock");
        send("L");repeat(5)@(negedge clk);if(!dut.expression_locked)$fatal(1,"lock");
        send("R");repeat(5)@(negedge clk);if(!dut.expression_locked || dut.expression_gain!=256)$fatal(1,"reset full volume");
        send("v");send("x");send(">");if(!dut.vibrato_enabled || dut.room_enabled || dut.octave!=2)$fatal(1,"effects/octave");
        send("r");send("V");send("<");if(dut.vibrato_enabled || !dut.room_enabled || dut.octave!=1)$fatal(1,"effect restore");
        send("Q");send("F");send("X");repeat(5)@(negedge clk);
        if(dut.pc_keys!=0 || dut.sustain || dut.key_command_state!=0)$fatal(1,"panic must interrupt partial packet");
        send("Q");send("F");send("F");send("F");send("5");send(";");repeat(5000)@(negedge clk);
        if(dut.voice_count!=12)$fatal(1,"12 voices end to end");
        send("H");send("F");send("F");send("F");send("5");send(";");repeat(12000)@(negedge clk);
        if(dut.pc_keys!=24'hffffff || dut.voice_count!=24)$fatal(1,"two-octave 24-voice chord");
        send("Q");send("D");send("D");send("D");send("7");send(";");
        send("H");send("0");send("0");send("7");send("D");send(";");
        if(dut.pc_keys!=24'h007ddd)$fatal(1,"Hex D in note payload/checksum must remain data");
        send("T");send("0");send("7");send("8");send("5");send(";");
        if(dut.metronome_bpm!=120)$fatal(1,"120 BPM metronome packet");
        wait(dut.watchdog==600000);repeat(5)@(negedge clk);if(dut.pc_keys!=0||dut.stream_enabled||dut.sustain)$fatal(1,"watchdog");
        if(dut.overrun||dut.stream_overflow||pa_en)$fatal(1,"audio overflow or unintended amplifier");
        $display("PASS CONTROL TOP: all 11 volume steps and display, USB diagnostics, atomic chords, checksum rejection, sustain, lock/reset, 8 timbres, effects, watchdog");$finish;
    end
    initial begin #20000000;$fatal(1,"top timeout");end
endmodule
