`timescale 1ns/1ps
module tb_room;
    reg clk=0;always #5 clk=~clk;reg rst=1,sample_tick=0,enabled=1;reg signed [15:0] dry=0;wire signed [15:0] wet;
    room_reverb dut(.*);integer nonzero=0,late_peak=0;
    task frame(input integer value);
        begin @(negedge clk);dry=value;sample_tick=1;@(negedge clk);sample_tick=0;repeat(4)@(negedge clk);
            if(wet===16'bx)$fatal(1,"uninitialized reverb RAM escaped");
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;frame(16000);if(wet!=14000)$fatal(1,"dry gain");
        for(integer i=1;i<70000;i=i+1)begin frame(0);if(wet!=0)nonzero++;if(i>60000 && (wet>32 || wet< -32))late_peak++;end
        if(nonzero<20 || late_peak!=0)$fatal(1,"reverb tail absent or unstable");
        enabled=0;frame(-12345);if(wet!=-12345)$fatal(1,"reverb bypass");
        $display("PASS ROOM: initialized memory, decaying impulse response, bounded tail and signed bypass");$finish;
    end
endmodule
