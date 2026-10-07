`timescale 1ns/1ps
module tb_studio_two_rows;
    reg clk=0,reset=1,frame_blank=0;
    always #5 clk=~clk;
    reg [10:0] x=0;
    reg [9:0] y=0;
    reg [23:0] keys=0;
    reg [2:0] timbre=0;
    reg [7:0] peak=0;
    reg signed [7:0] waveform=0;
    wire [23:0] rgb;
    studio_scene dut(.clk(clk),.reset(reset),.frame_blank(frame_blank),
        .video_x(x),.video_y(y),.keys(keys),.timbre(timbre),
        .voices(5'd4),.volume(9'd256),.octave(2'd1),.flags(8'd0),
        .peak(peak),.bpm(8'd120),.beat(1'b1),.song_status(8'd0),
        .usb_diag(8'd9),.waveform(waveform),.rgb(rgb));
    task frame_tick;
        begin
            @(negedge clk);frame_blank=1;
            @(negedge clk);frame_blank=0;
        end
    endtask
    integer fd,xx,yy;
    task render(input [255:0] path,input integer sounding);
        begin
            fd=$fopen(path,"wb");
            if(!fd)$fatal(1,"Cannot open scene output");
            $fwrite(fd,"P6\n640 480\n255\n");
            for(yy=0;yy<480;yy=yy+1)begin
                for(xx=0;xx<640;xx=xx+1)begin
                    @(negedge clk);x=xx;y=yy;
                    waveform=sounding?(((xx%64)<32?(xx%32)*6:186-(xx%32)*6)-93):0;
                    repeat(3)@(posedge clk);
                    #1;$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
                end
            end
            $fclose(fd);
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);reset=0;
        render("build/two_rows_idle.ppm",0);
        keys=(24'h1<<12)|(24'h1<<16)|(24'h1<<1)|(24'h1<<7);peak=180;
        repeat(4)frame_tick();
        if(dut.travel[12]!=4 || dut.travel[1]!=4 || dut.travel[0]!=0)
            $fatal(1,"Wrong key depression");
        render("build/two_rows_play.ppm",1);
        keys=0;repeat(4)frame_tick();
        if(dut.travel[12]!=0 || dut.travel[1]!=0)$fatal(1,"Key did not rebound");
        $display("two-row scene, key depression and rebound PASS");
        $finish;
    end
endmodule
