`timescale 1ns/1ps
module tb_i2c_reg_xfer;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,start=0,write=0;
    reg [6:0] address=7'h68;
    reg [7:0] reg_address=8'h3b,write_data=8'h01;
    reg [4:0] read_count=14;
    tri1 scl,sda;
    reg slave_sda_low=0,slave_scl_low=0;
    assign scl=slave_scl_low?1'b0:1'bz;
    assign sda=slave_sda_low?1'b0:1'bz;
    wire busy,done;
    wire [1:0] result;
    wire [127:0] read_data;
    i2c_reg_xfer #(.CLK_HZ(1000000),.BUS_HZ(50000),.TIMEOUT_CYCLES(500)) dut(.*);
    task launch;
        begin @(negedge clk);start=1;@(negedge clk);start=0;end
    endtask
    task start_condition;
        begin @(negedge sda);if(scl!==1) $fatal(1,"START without clock high");end
    endtask
    task receive(input [7:0] expected,input ack);
        reg [7:0] value;
        begin
            for(integer i=7;i>=0;i--) begin @(posedge scl);value[i]=sda;end
            if(value!==expected)$fatal(1,"wire byte %h expected %h",value,expected);
            @(negedge scl);slave_sda_low=ack;@(posedge scl);@(negedge scl);slave_sda_low=0;
        end
    endtask
    task stop_condition;
        begin : wait_stop
            forever begin @(posedge sda);if(scl===1)disable wait_stop;end
        end
    endtask
    task transmit(input [7:0] value,input more);
        begin
            for(integer i=7;i>=0;i--)begin slave_sda_low=!value[i];@(posedge scl);@(negedge scl);end
            slave_sda_low=0;@(posedge scl);
            if(sda!==!more)$fatal(1,"master ACK/NACK mismatch");
            @(negedge scl);
        end
    endtask
    task burst_slave(input integer count);
        begin
            start_condition();receive(8'hd0,1);receive(8'h3b,1);
            slave_scl_low=1;repeat(70)@(negedge clk);slave_scl_low=0;
            start_condition();receive(8'hd1,1);
            for(integer j=0;j<count;j++) transmit((j*19+8'h80)&255,j<count-1);
            stop_condition();
        end
    endtask
    task check(input [1:0] expected);
        begin @(posedge done);#1;if(result!==expected)$fatal(1,"result %d expected %d",result,expected);
            if(scl!==1 || sda!==1)$fatal(1,"pins not released at done");repeat(10)@(negedge clk);end
    endtask
    reg [127:0] expected;
    initial begin
        repeat(5)@(negedge clk);rst=0;
        for(integer count=1;count<=16;count++) begin
            read_count=count;expected=0;
            for(integer j=0;j<count;j++)expected=(expected<<8)|((j*19+8'h80)&255);
            fork launch();burst_slave(count);check(0);join
            if(read_data!==expected)$fatal(1,"burst ordering/count %d %h %h",count,read_data,expected);
        end
        write=1;reg_address=8'h6b;
        fork
            launch();check(0);
            begin start_condition();receive(8'hd0,1);receive(8'h6b,1);receive(8'h01,1);stop_condition();end
        join
        fork launch();check(1);join
        fork
            launch();check(1);
            begin start_condition();receive(8'hd0,1);receive(8'h6b,0);stop_condition();end
        join
        fork
            launch();check(1);
            begin start_condition();receive(8'hd0,1);receive(8'h6b,1);receive(8'h01,0);stop_condition();end
        join
        slave_scl_low=1;repeat(5)@(negedge clk);
        fork
            launch();
            begin @(posedge done);#1;if(result!=2 || dut.scl_low || dut.sda_low)$fatal(1,"stretch timeout/release");end
        join
        slave_scl_low=0;repeat(10)@(negedge clk);
        slave_sda_low=1;repeat(10)@(negedge clk);
        fork
            launch();check(2);
            begin
                repeat(3)@(posedge scl);@(negedge scl);slave_sda_low=0;
                repeat(6)@(posedge scl);@(negedge scl);stop_condition();
            end
        join
        write=0;reg_address=8'h3b;read_count=14;
        fork launch();burst_slave(14);check(0);join
        $display("PASS I2C XFER: 1..16 byte reads, all master ACKs/final NACK, write, all write NACK stages, stretching/timeout/recovery");$finish;
    end
    initial begin #5000000;$fatal(1,"xfer watchdog");end
endmodule
