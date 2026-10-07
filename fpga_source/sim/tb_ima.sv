`timescale 1ns/1ps
module tb_ima;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,start=0;reg signed [15:0] sample=0;
    wire done;wire [3:0] code;wire signed [15:0] predictor;wire [6:0] step_index;
    ima_encoder dut(.*);
    integer fh,n,a,b,packed_code,pred,index,count=0;
    task encode(input integer value,input integer expected);
        begin @(negedge clk);sample=value;start=1;@(negedge clk);start=0;
            wait(done);@(negedge clk);if(code!==expected[3:0])$fatal(1,"codec nibble mismatch at pair %d got %d expected %d",count,code,expected);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        fh=$fopen("sim/fixtures/ima_reference.txt","r");if(!fh)$fatal(1,"reference file missing");
        while(!$feof(fh))begin
            n=$fscanf(fh,"%d %d %d %d %d\n",a,b,packed_code,pred,index);
            if(n==5)begin
                encode(a,packed_code>>4);encode(b,packed_code&15);
                if($signed(predictor)!=pred || step_index!=index)$fatal(1,"codec state mismatch");count=count+1;
            end
        end
        if(count<2000)$fatal(1,"not enough codec vectors");
        $display("PASS IMA: independent CPython audioop vectors, signed limits, predictor and index states");$finish;
    end
    initial begin #5000000;$fatal(1,"codec timeout");end
endmodule
