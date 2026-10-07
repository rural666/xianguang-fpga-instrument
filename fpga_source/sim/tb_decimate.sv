`timescale 1ns/1ps
module tb_decimate;
    reg clk=0;always #5 clk=~clk;reg rst=1,sample_tick=0;reg signed [15:0] pcm=0;
    wire tick;wire signed [15:0] sample;audio_decimate dut(.*);
    integer history[0:5];integer expected,nout=0;
    initial begin
        for(integer i=0;i<6;i++)history[i]=0;
        repeat(4)@(negedge clk);rst=0;
        for(integer n=0;n<4096;n++)begin
            pcm=(n%4==0)?32767:(n%4==1)?-32768:(n*37)%32768;
            expected=(16*history[2]+9*(history[1]+history[3])-pcm-history[5])>>>5;
            if(expected>32767)expected=32767;if(expected< -32768)expected=-32768;
            @(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;
            if(tick !== n[0])$fatal(1,"half-rate cadence");
            if(tick)begin if($signed(sample)!=expected)$fatal(1,"FIR overflow/sign mismatch");nout++;end
            for(integer i=5;i>0;i--)history[i]=history[i-1];history[0]=pcm;
            repeat(2)@(negedge clk);
        end
        if(nout!=2048)$fatal(1,"output count");
        $display("PASS DECIMATE: independent integer FIR, signed boundaries, clipping, exact half-rate cadence");$finish;
    end
endmodule
