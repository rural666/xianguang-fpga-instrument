`timescale 1ns/1ps
module tb_metronome_audio;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,tick=0;reg [7:0] bpm=0;
    wire signed [15:0] click,out;wire flash,fault;
    metronome m(.clk(clk),.rst(rst),.sample_tick(tick),.bpm(bpm),.click(click),.flash(flash));
    speaker_conditioner s(.clk(clk),.rst(rst),.sample_tick(tick),.pcm_in(click),.voices(5'd0),.pcm_out(out),.limit_fault(fault));
    integer peak=0;
    initial begin
        repeat(5)@(negedge clk);rst=0;bpm=120;
        repeat(1500)begin
            @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(574)@(negedge clk);
            if(out>peak)peak=out;
        end
        $display("METRONOME AUDIO peak=%0d fault=%0d",peak,fault);
        if(peak<5000)$fatal(1,"Click is too quiet");
        $finish;
    end
endmodule
