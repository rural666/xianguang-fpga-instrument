`timescale 1ns/1ps
module tb_speaker_conditioner;
    reg clk=0;always #5 clk=~clk;reg rst=1,sample_tick=0;
    reg signed [15:0] pcm_in=0;wire signed [15:0] pcm_out;wire limit_fault;
    reg [4:0] voices=1;
    speaker_conditioner dut(.*);
    reg [15:0] samples[0:28047];integer n,f,peak=0;
    always @(posedge limit_fault)$display("LIMIT TRACE n=%0d delayed=%0d gain=%0d peak=%0d target=%0d product=%0d",n,dut.delayed,dut.gain,dut.peak,dut.target_gain,dut.product);
    initial begin
        $readmemh("sim/fixtures/speaker_conditioner.hex",samples);
        f=$fopen("build/sim/speaker_conditioner.txt","w");
        repeat(5)@(negedge clk);rst=0;
        for(n=0;n<28048;n=n+1)begin
            voices=n>=17048?3:1;
            pcm_in=samples[n];sample_tick=1;@(negedge clk);sample_tick=0;repeat(31)@(negedge clk);
            if(pcm_out>31000 || pcm_out < -31000)$fatal(1,"conditioner output out of range");
            if(n<60 && pcm_out!=0)$fatal(1,"uninitialized delay RAM escaped");
            if(dut.busy)$fatal(1,"gain division did not finish before next sample");
            if(pcm_out>peak)peak=pcm_out;
            $fdisplay(f,"%0d %0d %0d %0d %0d %0d %0d",n,$signed(pcm_out),dut.gain,dut.peak,dut.hold_peak,$signed(dut.delayed),$signed(dut.filtered));
        end
        $fclose(f);
        if(limit_fault)$fatal(1,"look-ahead failed to prevent clipping");
        if(peak<25000)$fatal(1,"loudness compensation missing");
        if(pcm_out>16 || pcm_out< -16)$fatal(1,"silence did not settle");
        $display("PASS speaker conditioner: initialized look-ahead, headroom, no clipping fallback, sustained gain, zero tail");$finish;
    end
endmodule
