`default_nettype none
// Half-band FIR [-1,0,9,16,9,0,-1]/32, then /2 sample-rate conversion.
module audio_decimate(input wire clk,rst,sample_tick,input wire signed [15:0] pcm,output reg tick,output reg signed [15:0] sample);
    reg signed [15:0] d0,d1,d2,d3,d4,d5;
    reg parity;
    wire signed [21:0] center=$signed(d2);
    wire signed [21:0] adjacent=$signed(d1)+$signed(d3);
    wire signed [21:0] edges=$signed(pcm)+$signed(d5);
    wire signed [21:0] total=(center<<<4)+(adjacent<<<3)+adjacent-edges;
    wire signed [21:0] result=total>>>5;
    always @(posedge clk)begin
        if(rst)begin d0<=0;d1<=0;d2<=0;d3<=0;d4<=0;d5<=0;parity<=0;tick<=0;sample<=0;end
        else begin
            tick<=0;
            if(sample_tick)begin
                d0<=pcm;d1<=d0;d2<=d1;d3<=d2;d4<=d3;d5<=d4;parity<=!parity;
                if(parity)begin
                    tick<=1;
                    if(result>32767)sample<=32767;else if(result< -32768)sample<=-32768;else sample<=result[15:0];
                end
            end
        end
    end
endmodule
`default_nettype wire
