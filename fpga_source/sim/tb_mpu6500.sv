`timescale 1ns/1ps
module tb_mpu6500 #(parameter CHIP_ID=8'h70);
    reg clk=0;always #5 clk=~clk;
    reg rst=1;
    tri1 scl,sda;
    reg low=0;
    assign sda=low?1'b0:1'bz;
    wire online,sample_valid;
    wire [2:0] status;
    wire [6:0] address;
    wire [7:0] whoami;
    wire [31:0] samples;
    wire [15:0] errors;
    wire signed [15:0] ax,ay,az,temperature,gx,gy,gz;
    mpu6050_reader #(.CLK_HZ(1000000),.BUS_HZ(50000),.TIMEOUT_CYCLES(500),
        .BOOT_CYCLES(100),.RETRY_CYCLES(100),.POLL_CYCLES(50)) dut(.*);
    task start_condition;
        begin : find_start
            forever begin @(negedge sda);if(scl===1)disable find_start;end
        end
    endtask
    task stop_condition;
        begin : find_stop
            forever begin @(posedge sda);if(scl===1)disable find_stop;end
        end
    endtask
    task receive(input [7:0] expected,input ack);
        reg [7:0] value;
        begin
            for(integer i=7;i>=0;i--)begin @(posedge scl);value[i]=sda;end
            if(value!==expected)$fatal(1,"MPU transaction byte %h expected %h",value,expected);
            @(negedge scl);low=ack;@(posedge scl);@(negedge scl);low=0;
        end
    endtask
    task read_register(input [7:0] regnum,input integer length,input [127:0] value);
        reg [7:0] byteval;
        begin
            start_condition();receive(8'hd2,1);receive(regnum,1);
            start_condition();receive(8'hd3,1);
            for(integer j=0;j<length;j++)begin
                byteval=value>>(8*(length-1-j));
                for(integer i=7;i>=0;i--)begin low=!byteval[i];@(posedge scl);@(negedge scl);end
                low=0;@(posedge scl);
                if(sda!==(j==length-1))$fatal(1,"MPU master burst ACK");
                @(negedge scl);
            end
            stop_condition();
        end
    endtask
    task write_register(input [7:0] regnum,value);
        begin start_condition();receive(8'hd2,1);receive(regnum,1);receive(value,1);stop_condition();end
    endtask
    task initialize_sensor(input bad_config);
        begin
            start_condition();receive(8'hd0,0);stop_condition(); // device deliberately lives at 0x69
            read_register(8'h75,1,CHIP_ID);
            write_register(8'h6b,8'h01);write_register(8'h6c,8'h00);
            write_register(8'h1a,8'h03);write_register(8'h19,8'h13);
            write_register(8'h1b,8'h00);write_register(8'h1c,8'h00);
            if(CHIP_ID==8'h70)begin
                write_register(8'h1d,8'h03);
                read_register(8'h19,5,bad_config ? 40'h1303000803:40'h1303000003);
            end else read_register(8'h19,4,bad_config ? 32'h13030008:32'h13030000);
            if(!bad_config)read_register(8'h6b,2,16'h0100);
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        wait(errors>=2);if(online || samples!=0)$fatal(1,"absent sensor became online");
        initialize_sensor(0);
        read_register(8'h3b,14,112'h1234fe00400000000010ffe00003);
        wait(sample_valid);#1;
        if(!online||status!=0||whoami!=CHIP_ID||address!='h69||samples!=1)$fatal(1,"MPU identity/ready state");
        if(ax!='h1234||ay!=-512||az!=16384||temperature!=0||gx!=16||gy!=-32||gz!=3)$fatal(1,"MPU burst endian/signed decode");
        start_condition();receive(8'hd2,0);stop_condition();
        wait(!online);#1;if(samples!=1||sample_valid||status!=1)$fatal(1,"disconnect published invalid sample");
        initialize_sensor(1);
        wait(status==4);#1;if(online||samples!=1)$fatal(1,"failed configuration accepted");
        $display("PASS MPU: absence/retry, alternate address, identity, config writes/readback, signed 14-byte snapshot, disconnect and bad-config rejection");$finish;
    end
    initial begin #2000000;$fatal(1,"MPU watchdog");end
endmodule

