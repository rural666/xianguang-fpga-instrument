`default_nettype none
// DVI-compatible HDMI video encoding, one 10-bit symbol per pixel.
module tmds_encoder(
    input wire clk,reset,de,input wire [7:0] data,input wire [1:0] control,
    output reg [9:0] symbol=10'b1101010100
);
    reg signed [6:0] disparity=0,next_disparity;
    reg [9:0] next_symbol;
    reg [8:0] qm;
    reg use_xnor;
    integer i,ones_data,ones_q,balance;
    always @*begin
        ones_data=0;
        for(i=0;i<8;i=i+1)if(data[i])ones_data=ones_data+1;
        use_xnor=ones_data>4 || (ones_data==4 && !data[0]);
        qm[0]=data[0];
        for(i=1;i<8;i=i+1)qm[i]=qm[i-1]^data[i]^use_xnor;
        qm[8]=!use_xnor;
        ones_q=0;
        for(i=0;i<8;i=i+1)if(qm[i])ones_q=ones_q+1;
        balance=2*ones_q-8;
        next_disparity=disparity;
        next_symbol=10'b1101010100;
        if(!de)begin
            case(control)
                2'b00:next_symbol=10'b1101010100;
                2'b01:next_symbol=10'b0010101011;
                2'b10:next_symbol=10'b0101010100;
                2'b11:next_symbol=10'b1010101011;
            endcase
            next_disparity=0;
        end else if(disparity==0 || balance==0)begin
            next_symbol={~qm[8],qm[8],qm[8]?qm[7:0]:~qm[7:0]};
            next_disparity=disparity+(qm[8]?balance:-balance);
        end else if((disparity>0 && balance>0)||(disparity<0 && balance<0))begin
            next_symbol={1'b1,qm[8],~qm[7:0]};
            next_disparity=disparity+(qm[8]?2:0)-balance;
        end else begin
            next_symbol={1'b0,qm[8],qm[7:0]};
            next_disparity=disparity+balance-(qm[8]?0:2);
        end
    end
    always @(posedge clk)begin
        if(reset)begin symbol<=10'b1101010100;disparity<=0;end
        else begin symbol<=next_symbol;disparity<=next_disparity;end
    end
endmodule
`default_nettype wire
