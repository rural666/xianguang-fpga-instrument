`timescale 1ns/1ps
module tb_metronome;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,sample_tick=1;reg [7:0] bpm=0;
    wire signed [15:0] click;wire flash;
    metronome dut(.*);
    integer n,first=-1,second=-1,events=0;
    reg prior=0;
    initial begin
        repeat(4)@(negedge clk);rst=0;
        repeat(100)@(negedge clk);
        if(click!=0 || flash)$fatal(1,"metronome must be silent when disabled");
        bpm=120;
        for(n=0;n<50000;n=n+1)begin
            @(negedge clk);
            if(flash && !prior)begin
                if(events==0)first=n;
                if(events==1)second=n;
                events=events+1;
            end
            prior=flash;
            if(n==10 && click==0)$fatal(1,"first beat has no audible click");
        end
        if(events!=3 || second-first<23437 || second-first>23439)
            $fatal(1,"120 BPM interval incorrect: %0d events, %0d samples",events,second-first);
        bpm=0;
        repeat(5)@(negedge clk);
        if(click!=0 || flash)$fatal(1,"F10 off must stop click and flash");
        $display("PASS METRONOME: silent off, click and display pulse on, 120 BPM interval");
        $finish;
    end
endmodule
