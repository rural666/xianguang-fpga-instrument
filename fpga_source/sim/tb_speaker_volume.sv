`timescale 1ns/1ps
module tb_speaker_volume;
    reg clk=0;always #5 clk=~clk;reg rst=1,sample_tick=0;
    reg [8:0] target=256;reg signed [15:0] pcm_in=16000;
    wire signed [15:0] pcm_out;wire [8:0] applied;
    speaker_volume dut(.*);
    task tick;begin @(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;repeat(4)@(negedge clk);end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);
        if(applied!=256 || pcm_out!=16000)$fatal(1,"full gain");
        target=128;tick();if(applied!=255)$fatal(1,"smooth volume decrease");
        repeat(140)tick();if(applied!=128 || pcm_out!=8000)$fatal(1,"half gain");
        pcm_in=-16000;repeat(5)@(negedge clk);if(pcm_out!=-8000)$fatal(1,"signed gain");
        target=0;repeat(140)tick();if(applied!=0 || pcm_out!=0)$fatal(1,"mute");
        target=511;tick();if(applied!=1)$fatal(1,"smooth volume increase");
        repeat(270)tick();if(applied!=256 || pcm_out!=-16000)$fatal(1,"clamp gain");
        pcm_in=-32768;repeat(5)@(negedge clk);if(pcm_out!=-32768)$fatal(1,"negative full scale overflow");
        pcm_in=32767;repeat(5)@(negedge clk);if(pcm_out!=32767)$fatal(1,"positive full scale overflow");
        $display("PASS speaker volume: signed PCM, mute, half/full scale, ramp, gain clamp, numeric limits");$finish;
    end
endmodule
