`timescale 1ns/1ps
module tb_adpcm6;
    reg clk=0;always #5 clk=~clk;reg rst=1,start=0;reg signed [15:0] sample=0;
    wire done;wire [5:0] code;wire signed [15:0] predictor;wire [6:0] step_index;
    adpcm6_encoder dut(.*);integer fd,n,value,expected,pred,index,count=0;
    initial begin
        repeat(4)@(negedge clk);rst=0;
        fd=$fopen("sim/fixtures/adpcm6_reference.txt","r");if(!fd)$fatal(1,"missing codec6 reference");
        while(!$feof(fd))begin
            n=$fscanf(fd,"%d %d %d %d\n",value,expected,pred,index);
            if(n==4)begin
                @(negedge clk);sample=value;start=1;@(negedge clk);start=0;wait(done);@(negedge clk);
                if(code!==expected[5:0] || $signed(predictor)!=pred || step_index!=index)$fatal(1,"codec6 reference mismatch at %d",count);
                count=count+1;
            end
        end
        if(count<10000)$fatal(1,"too few reference vectors");
        $display("PASS ADPCM6: %d independent level-table vectors, full signed range, predictor saturation and silence",count);$finish;
    end
    initial begin #5000000;$fatal(1,"codec6 timeout");end
endmodule
