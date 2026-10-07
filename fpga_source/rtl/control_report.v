`default_nettype none
module control_report #(parameter integer REPORT_CYCLES=5400000)(
    input wire clk,rst, input wire [2:0] status,input wire [6:0] address,input wire [7:0] whoami,
    input wire [31:0] samples,input wire [15:0] errors,ax,ay,az,tp,gx,gy,gz,
    input wire [2:0] timbre,input wire expression_enabled,input wire [8:0] gain,
    input wire [31:0] position,input wire [15:0] presses,commands,input wire [7:0] rx,output wire tx
);
    function [7:0] hx;
        input [3:0] x;
        begin hx=(x<10)?8'h30+x:8'h41+x-10; end
    endfunction
    function [15:0] h8;
        input [7:0] x;
        begin h8={hx(x[7:4]),hx(x[3:0])}; end
    endfunction
    function [31:0] h16;
        input [15:0] x;
        begin h16={h8(x[15:8]),h8(x[7:0])}; end
    endfunction
    function [63:0] h32;
        input [31:0] x;
        begin h32={h16(x[31:16]),h16(x[15:0])}; end
    endfunction
    localparam integer MSG_LEN=164;
    reg [MSG_LEN*8-1:0] message;
    reg [7:0] index;
    reg [1:0] state;
    reg start;
    reg [7:0] data;
    wire busy;
    reg [31:0] timer,reports;
    uart_tx #(.BAUD(230400)) uart(.clk(clk),.rst(rst),.start(start),.data(data),.tx(tx),.busy(busy));
    always @(posedge clk) begin
        if(rst) begin message<=0;index<=0;state<=0;start<=0;data<=0;timer<=0;reports<=0;end
        else begin
            start<=0;
            if(timer!=REPORT_CYCLES-1) timer<=timer+1'b1;
            case(state)
                0:if(timer==REPORT_CYCLES-1) begin
                    timer<=0;reports<=reports+1'b1;
                    message<={"TN20K_CTL5 H=",h32(reports),
                        " M=",hx({1'b0,status}),
                        " A=",h8({1'b0,address}),
                        " ID=",h8(whoami),
                        " N=",h32(samples),
                        " ERR=",h16(errors),
                        " AX=",h16(ax),
                        " AY=",h16(ay),
                        " AZ=",h16(az),
                        " GX=",h16(gx),
                        " GY=",h16(gy),
                        " GZ=",h16(gz),
                        " TP=",h16(tp),
                        " T=",hx({1'b0,timbre}),
                        " E=",hx({3'b0,expression_enabled}),
                        " G=",h16({7'b0,gain}),
                        " POS=",h32(position),
                        " BTN=",h16(presses),
                        " RX=",h8(rx),
                        " C=",h16(commands),8'h0d,8'h0a};
                    index<=0;state<=1;
                end
                1:if(!busy) begin data<=message[MSG_LEN*8-1-:8];start<=1;state<=2;end
                2:state<=3;
                3:if(!busy) begin
                    if(index==MSG_LEN-1) state<=0;
                    else begin message<=message<<8;index<=index+1'b1;state<=1;end
                end
            endcase
        end
    end
endmodule
`default_nettype wire
