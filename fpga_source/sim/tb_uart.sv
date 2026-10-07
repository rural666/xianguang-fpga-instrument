`timescale 1ns/1ps
module tb_uart;
    reg clk=0; always #5 clk=~clk;
    localparam DIV=234;
    reg rst=1,start=0,rx=1;
    reg [7:0] data=0;
    wire tx,busy,valid,framing_error;
    wire [7:0] received;
    integer nvalid=0, nerror=0;
    uart_tx dut_tx(.clk(clk),.rst(rst),.start(start),.data(data),.tx(tx),.busy(busy));
    uart_rx dut_rx(.clk(clk),.rst(rst),.rx(rx),.valid(valid),.data(received),.framing_error(framing_error));
    always @(posedge clk) begin
        if(valid) nvalid=nvalid+1;
        if(framing_error) nerror=nerror+1;
    end
    task rx_byte(input [7:0] value,input stop_ok);
        integer i;
        begin
            @(negedge clk); rx=0; repeat(DIV) @(negedge clk);
            for(i=0;i<8;i=i+1) begin rx=value[i]; repeat(DIV) @(negedge clk); end
            rx=stop_ok; repeat(DIV) @(negedge clk);
            rx=1; repeat(DIV) @(negedge clk);
        end
    endtask
    task tx_byte(input [7:0] value);
        reg [7:0] decoded;
        integer i;
        begin
            fork
                begin @(negedge clk); data=value; start=1; @(negedge clk); start=0; end
                begin
                    @(negedge tx); repeat(DIV/2) @(negedge clk);
                    if(tx!==0) $fatal(1,"TX start bit");
                    for(i=0;i<8;i=i+1) begin repeat(DIV) @(negedge clk); decoded[i]=tx; end
                    repeat(DIV) @(negedge clk);
                    if(tx!==1 || decoded!==value) $fatal(1,"TX decode %h expected %h",decoded,value);
                end
            join
            wait(!busy); repeat(3) @(negedge clk);
        end
    endtask
    initial begin
        #1000000; $fatal(1,"UART watchdog");
    end
    initial begin
        repeat(5) @(negedge clk); rst=0;
        tx_byte(0); tx_byte(8'hff); tx_byte(8'ha5); tx_byte(8'h5a);
        rx_byte(8'h53,1);
        if(nvalid!=1 || received!=8'h53) $fatal(1,"RX first byte");
        rx_byte(8'hc6,1);
        if(nvalid!=2 || received!=8'hc6) $fatal(1,"RX second byte");
        rx_byte(8'h91,0);
        if(nvalid!=2 || nerror==0) $fatal(1,"bad stop bit accepted");
        @(negedge clk); rx=0; repeat(10) @(negedge clk); rx=1;
        repeat(400) @(negedge clk);
        if(nvalid!=2) $fatal(1,"false start accepted");
        $display("PASS UART: TX wire decoding, RX bytes, bad stop rejection, false start rejection");
        $finish;
    end
endmodule
