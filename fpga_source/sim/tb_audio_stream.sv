`timescale 1ns/1ps
module tb_audio_stream;
    reg clk=0;always #5 clk=~clk;reg rst=1,sample_tick=0;reg signed [15:0] pcm=0;
    wire tx,overflow;integer cadence=0,samples=0,fd;
    audio_uart_stream dut(.clk(clk),.rst(rst),.sample_tick(sample_tick),.pcm(pcm),.flags(8'hc4),
        .expression_meta(16'h2a40),.keys(12'h091),.timbre(3'd1),.voices(4'd3),.octave(2'd1),.room(1'b1),.vibrato_depth(7'd23),.tx(tx),.overflow(overflow));
    initial begin repeat(5)@(negedge clk);rst=0;end
    always @(negedge clk)if(!rst)begin
        sample_tick=0;
        if(cadence==1151)begin cadence=0;sample_tick=1;pcm=(samples*523)%24000-12000;samples=samples+1;end
        else cadence=cadence+1;
    end
    reg [7:0] bytes[0:121];reg [15:0] crc;
    initial begin
        fd=$fopen("build/sim/adpcm_packets.bin","wb");
        for(integer packet=0;packet<32;packet++)begin
            for(integer n=0;n<122;n++)begin
                @(negedge tx);repeat(58)@(negedge clk);if(tx!==0)$fatal(1,"UART start");
                for(integer b=0;b<8;b++)begin repeat(117)@(negedge clk);bytes[n][b]=tx;end
                repeat(117)@(negedge clk);if(tx!==1)$fatal(1,"UART stop");$fwrite(fd,"%c",bytes[n]);
            end
            if({bytes[0],bytes[1],bytes[2],bytes[3]}!="T20A" || bytes[4]!=4 || {bytes[7],bytes[6]}!=packet)$fatal(1,"header/sequence");
            if({bytes[11],bytes[10],bytes[9],bytes[8]}!=46875 || {bytes[13],bytes[12]}!=128)$fatal(1,"audio format");
            if(bytes[5]!=8'hc4 || {bytes[15],bytes[14]}!=16'h2a40 || {bytes[17],bytes[16]}!=16'h1091)$fatal(1,"gain/lock/key metadata");
            if(bytes[18]!=17 || bytes[19]!=3 || bytes[22]>88 || bytes[23]!=23)$fatal(1,"timbre/voice/codec metadata");
            crc=16'hffff;for(integer n=4;n<120;n++)for(integer b=7;b>=0;b--)crc=crc[15]^bytes[n][b]?{crc[14:0],1'b0}^16'h1021:{crc[14:0],1'b0};
            if({bytes[121],bytes[120]}!=crc)$fatal(1,"CRC");if(overflow)$fatal(1,"transport overflow");
        end
        $fclose(fd);$display("PASS AUDIO STREAM: UART wire decode, v4 metadata, CRC, 4096 samples and FIFO wrap");$finish;
    end
    initial begin #60000000;$fatal(1,"stream timeout");end
endmodule
