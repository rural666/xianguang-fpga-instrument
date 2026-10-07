`timescale 1ns/1ps
module tb_control_report;
    reg clk=0;always #5 clk=~clk;
    reg rst=1;
    wire tx;
    control_report #(.REPORT_CYCLES(1000)) dut(.clk(clk),.rst(rst),.status(3'd0),.address(7'h68),.whoami(8'h68),
        .samples(32'd1234),.errors(16'd0),.ax(16'h8000),.ay(16'h1234),.az(16'h4000),.tp(16'd0),
        .gx(16'd0),.gy(16'd0),.gz(16'd0),.timbre(3'd3),.expression_enabled(1'b1),.gain(9'd192),
        .position(32'hffffffff),.presses(16'd2),.rx(8'h6d),.commands(16'd7),.tx(tx));
    initial begin repeat(5)@(negedge clk);rst=0;end
    reg [164*8-1:0] frame=0;
    reg [7:0] ch;
    initial begin
        for(integer n=0;n<164;n++)begin
            @(negedge tx);repeat(58)@(negedge clk);
            if(tx!==0)$fatal(1,"report start");
            for(integer b=0;b<8;b++)begin repeat(117)@(negedge clk);ch[b]=tx;end
            repeat(117)@(negedge clk);if(tx!==1)$fatal(1,"report stop");frame=(frame<<8)|ch;
        end
        if(frame!=={"TN20K_CTL5 H=00000000 M=0 A=68 ID=68 N=000004D2 ERR=0000 AX=8000 AY=1234 AZ=4000 GX=0000 GY=0000 GZ=0000 TP=0000 T=3 E=1 G=00C0 POS=FFFFFFFF BTN=0002 RX=6D C=0007",8'h0d,8'h0a})begin $display("%s",frame);$fatal(1,"report payload");end
        $display("PASS CONTROL REPORT: independent UART decode of every raw sensor/control field");$finish;
    end
    initial begin #3000000;$fatal(1,"report watchdog");end
endmodule
