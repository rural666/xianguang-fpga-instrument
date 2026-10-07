`timescale 1ns/1ps
module tb_speaker_path;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,tick=0;
    reg [23:0] keys=0;reg [2:0] timbre=0;
    wire signed [15:0] dry,room,out;
    wire active,overrun,limit_fault;wire [4:0] voices;
    synth_core #(.MASTER_SHIFT(4),.LINEAR_MIX(1)) synth(
        .clk(clk),.rst(rst),.sample_tick(tick),.keys(keys),.timbre(timbre),
        .sustain(1'b0),.octave(2'd1),.vibrato_depth(7'd0),
        .pcm(dry),.active(active),.overrun(overrun),.voice_count(voices));
    room_reverb reverb(.clk(clk),.rst(rst),.sample_tick(tick),.enabled(1'b1),.dry(dry),.wet(room));
    speaker_conditioner conditioner(.clk(clk),.rst(rst),.sample_tick(tick),.pcm_in(room),.voices(voices),.pcm_out(out),.limit_fault(limit_fault));
    integer file,n=0,stage=0,single_peak=0;
    task frames(input integer length);
        begin for(integer j=0;j<length;j=j+1)begin
            @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(574)@(negedge clk);
            if(overrun)$fatal(1,"audio deadline exceeded");
            if(dry==32767 || dry==-32767 || room==32767 || room==-32768)$fatal(1,"upstream mix hit numerical rail");
            if(limit_fault)$fatal(1,"speaker look-ahead missed a peak, stage %0d sample %0d",stage,n);
            if(stage==1 && out>single_peak)single_peak=out;
            $fdisplay(file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d",n,stage,voices,dry,room,out,conditioner.gain);
            n=n+1;
        end end
    endtask
    initial begin
        file=$fopen("build/sim/speaker_path.csv","w");
        repeat(5)@(negedge clk);rst=0;
        frames(128);if(out!=0)$fatal(1,"startup not silent");
        stage=1;keys=12'h200;frames(8000);
        if(single_peak<25000)$fatal(1,"single piano not raised to target range");
        stage=2;keys=0;frames(7000);
        stage=3;keys=12'h091;frames(10000);
        if(voices!=3)$fatal(1,"chord voice count");
        stage=4;keys=24'hffffff;frames(7000);
        if(voices!=24)$fatal(1,"all 24 voices missing");
        for(integer t=1;t<8;t=t+1)begin stage=4+t;timbre=t;frames(2000);end
        stage=12;keys=0;frames(12000);
        $fclose(file);
        $display("PASS speaker path: single piano loudness, three/24 voices, eight timbres, no upstream clipping or output fallback");$finish;
    end
endmodule
