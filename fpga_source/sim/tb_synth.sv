`timescale 1ns/1ps
module tb_synth;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,sample_tick=0,sustain=0;
    reg [23:0] keys=0;reg [2:0] timbre=0;reg [1:0] octave=1;reg [6:0] vibrato_depth=0;
    wire signed [15:0] pcm;wire active,overrun;wire [4:0] voice_count;
    synth_core dut(.*);integer fh,index=0,stage=0;
    task frames(input integer n);
        begin for(integer j=0;j<n;j=j+1)begin
            @(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;repeat(574)@(negedge clk);
            if(overrun)$fatal(1,"synthesis exceeded 576 clocks");
            if(pcm===16'bx)$fatal(1,"unknown PCM");
            $fwrite(fh,"%0d,%0d,%0d\n",index,stage,pcm);index=index+1;
        end end
    endtask
    initial begin
        fh=$fopen("build/sim/synth_samples.csv","w");repeat(4)@(negedge clk);rst=0;
        frames(32);if(active || pcm!=0)$fatal(1,"idle silence");
        stage=1;keys=12'h200;frames(9000);
        if(voice_count!=1 || dut.env_state[9]!=2)$fatal(1,"piano attack/decay");
        stage=2;frames(9000);
        sustain=1;keys=0;stage=3;frames(3000);
        if(!active || dut.env_state[9]!=2)$fatal(1,"sustain pedal did not preserve piano tail");
        sustain=0;stage=4;frames(24000);if(active || pcm!=0)$fatal(1,"damped release must end");
        stage=5;keys=12'h091;frames(4096);if(voice_count!=3)$fatal(1,"three-note chord");
        stage=6;keys=24'hffffff;frames(4096);if(voice_count!=24)$fatal(1,"24-voice chord");
        if(dut.note_step[12] != (dut.note_step[0]<<1))$fatal(1,"second octave pitch");
        for(integer t=1;t<8;t=t+1)begin timbre=t;frames(512);end
        keys=0;sustain=0;frames(24000);if(active || pcm!=0)$fatal(1,"final release");
        octave=2;timbre=2;keys=12'h200;frames(500);
        if(dut.note_step[9]!=80630852)$fatal(1,"octave step");
        force dut.vibrato_product=-16'sd16000;frames(5);
        if(dut.pitch_adjustment>=0)$fatal(1,"negative vibrato offset sign");release dut.vibrato_product;
        $fclose(fh);$display("PASS SYNTH: piano decay, sustain, 3/24 voice chords, 8 timbres, release, octave, negative vibrato");$finish;
    end
    initial begin #700000000;$fatal(1,"synth timeout");end
endmodule
