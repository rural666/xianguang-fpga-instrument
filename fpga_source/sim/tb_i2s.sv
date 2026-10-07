`timescale 1ns/1ps
module tb_i2s;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    reg signed [15:0] pcm=16'h8123;
    wire bclk,ws,din,sample_tick;
    i2s_tx dut(.*);
    integer clocks=0,last_tick=0;
    always @(posedge clk) begin
        clocks=clocks+1;
        if(sample_tick) begin
            if(last_tick!=0 && clocks-last_tick!=576) $fatal(1,"sample frame spacing");
            last_tick=clocks;
        end
    end
    task stereo(input [15:0] expected);
        reg [15:0] leftword,rightword;
        integer i;
        begin
            @(negedge ws); @(posedge bclk); // final bit of previous right channel
            for(i=15;i>=0;i=i-1) begin @(posedge bclk); leftword[i]=din; end
            for(i=15;i>=0;i=i-1) begin @(posedge bclk); rightword[i]=din; end
            if(leftword!==expected || rightword!==expected)
                $fatal(1,"I2S L=%h R=%h expected=%h",leftword,rightword,expected);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk); rst=0;
        stereo(16'h8123); pcm=16'h5678;
        stereo(16'h5678); pcm=16'hffff;
        stereo(16'hffff); pcm=0;
        stereo(0);
        $display("PASS I2S: MSB delay, channel polarity, 16-bit signed words, both channels, 576-clock frame");
        $finish;
    end
    initial begin #100000; $fatal(1,"I2S watchdog"); end
endmodule
