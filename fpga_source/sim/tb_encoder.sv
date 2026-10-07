`timescale 1ns/1ps
module tb_encoder;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,enc_a=1,enc_b=1,enc_sw=1;
    wire step_up,step_down,press;
    wire signed [31:0] position;
    wire [15:0] presses;
    wire [2:0] stable_pins;
    encoder_control #(.AB_FILTER(4),.SW_FILTER(12)) dut(.*);
    integer ups=0,downs=0,clicks=0;
    always @(posedge clk) begin #1;if(step_up)ups++;if(step_down)downs++;if(press)clicks++;end
    task pins(input [1:0] ab);
        begin @(negedge clk);{enc_a,enc_b}=ab;repeat(12)@(negedge clk);end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        pins(1);pins(0);pins(2);pins(3);
        pins(1);pins(3); // reverse before complete detent: no event
        pins(1);pins(0);pins(2);pins(3);
        pins(2);pins(0);pins(1);pins(3);
        if(position!=1||ups!=2||downs!=1)$fatal(1,"direction/partial reversal");
        pins(0);pins(3); // illegal transitions must not become steps
        repeat(8)begin
            {enc_a,enc_b}=1;repeat(3)@(negedge clk);
            {enc_a,enc_b}=2;repeat(3)@(negedge clk);
            if(stable_pins[2:1]!=3)$fatal(1,"changing candidates must not pass stable debounce");
        end
        pins(3);
        repeat(3)begin {enc_a,enc_b}=1;repeat(2)@(negedge clk);{enc_a,enc_b}=3;repeat(8)@(negedge clk);end
        if(position!=1||ups!=2||downs!=1)$fatal(1,"bounce/illegal transition");
        enc_sw=0;repeat(4)@(negedge clk);enc_sw=1;repeat(20)@(negedge clk);
        if(clicks!=0)$fatal(1,"switch glitch accepted");
        enc_sw=0;repeat(100)@(negedge clk);
        if(clicks!=1||presses!=1)$fatal(1,"hold should generate one press");
        enc_sw=1;repeat(30)@(negedge clk);enc_sw=0;repeat(30)@(negedge clk);
        if(clicks!=2||presses!=2)$fatal(1,"second press missing");
        $display("PASS ENCODER: both directions, reversal, glitches, illegal transitions, held-button single event");$finish;
    end
    initial begin #100000;$fatal(1,"encoder watchdog");end
endmodule
