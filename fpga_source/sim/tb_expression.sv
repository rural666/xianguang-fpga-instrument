`timescale 1ns/1ps
module tb_expression;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,sample_tick=1,sample_valid=0,enabled=0,online=0,calibrate=0;
    reg signed [15:0] ax=0,ay=0,az=16384,pcm_in=12345;
    wire signed [15:0] pcm_out;
    wire [8:0] gain;
    wire calibrated,calibrating,locked;
    reg lock_volume=0,unlock_volume=0,reset_volume=0;
    tilt_expression dut(.*);
    task samples(input integer n);
        begin
            for(integer i=0;i<n;i=i+1) begin
                @(negedge clk);sample_valid=1;
                @(negedge clk);sample_valid=0;repeat(6)@(negedge clk);
            end
        end
    endtask
    task settle;begin repeat(16000)@(negedge clk);end endtask
    task recalibrate;
        begin @(negedge clk);calibrate=1;@(negedge clk);calibrate=0;samples(16);settle;end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);
        if(pcm_out!=12345 || gain!=256 || calibrated)$fatal(1,"default bypass");
        enabled=1;online=1;unlock_volume=1;@(negedge clk);unlock_volume=0;repeat(5)@(negedge clk);samples(15);
        if(calibrated || !calibrating)$fatal(1,"must wait for 16 distinct samples");
        samples(1);settle;
        if(!calibrated || calibrating || gain!=256)$fatal(1,"stable neutral calibration");
        ax=8192;az=14189;settle;
        if(gain!=132)$fatal(1,"30 degree forward tilt mapping");
        lock_volume=1;@(negedge clk);lock_volume=0;
        ax=-16384;ay=16000;az=0;settle;
        if(!locked || gain!=132)$fatal(1,"locked volume changed under motion");
        online=0;settle;if(gain!=132)$fatal(1,"disconnect must preserve locked volume");
        reset_volume=1;@(negedge clk);reset_volume=0;settle;
        if(!locked || gain!=256)$fatal(1,"reset must lock at 100 percent");
        online=1;ax=0;ay=0;az=16384;recalibrate;
        unlock_volume=1;@(negedge clk);unlock_volume=0;
        ax=-8192;az=14189;settle;if(gain!=132)$fatal(1,"backward tilt symmetry");
        ax=0;ay=8192;settle;if(gain!=132)$fatal(1,"sideways tilt must work");
        ay=-8192;settle;if(gain!=132)$fatal(1,"opposite sideways tilt");
        pcm_in=-32768;repeat(5)@(negedge clk);if(pcm_out!=-16896)$fatal(1,"signed negative PCM");
        pcm_in=32767;repeat(5)@(negedge clk);if(pcm_out!=16895)$fatal(1,"positive PCM");
        ax=0;ay=0;az=16384;settle;if(gain!=256)$fatal(1,"return to neutral");
        ax=200;ay=-200;settle;if(gain!=256)$fatal(1,"noise dead zone");
        ax=16384;az=0;settle;if(gain!=32)$fatal(1,"large tilt lower clamp");
        recalibrate;if(!calibrated || gain!=256)$fatal(1,"manual recalibration");
        ax=-16384;settle;if(gain!=32)$fatal(1,"signed vector displacement");
        online=0;settle;if(gain!=256 || calibrated)$fatal(1,"disconnect bypass");
        online=1;repeat(5)@(negedge clk);
        for(integer i=0;i<24;i=i+1) begin ax=i[0]?0:8192;samples(1);end
        if(calibrated)$fatal(1,"movement must restart calibration");
        ax=32767;ay=-32768;az=1000;samples(16);settle;
        if(!calibrated || dut.baseline_x!=32767 || dut.baseline_y!=-32768 || gain!=256)$fatal(1,"calibration sum width");
        ax=-32768;ay=32767;settle;if(gain!=32)$fatal(1,"full signed input range");
        enabled=0;settle;if(gain!=256 || calibrated || calibrating)$fatal(1,"disabled bypass");
        $display("PASS EXPRESSION LOCK: both tilt axes, symmetry, stable calibration, signed limits, dead zone, PCM gain, recovery");$finish;
    end
    initial begin #5000000;$fatal(1,"expression watchdog");end
endmodule
