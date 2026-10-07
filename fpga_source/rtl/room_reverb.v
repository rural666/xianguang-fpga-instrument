`default_nettype none
// Four bounded feedback combs: unity worst-case DC gain including dry path.
// RAM is read only after each address has been initialized by a sample write.
module room_reverb(input wire clk,rst,sample_tick,enabled,input wire signed [15:0] dry,output reg signed [15:0] wet);
    reg signed [15:0] m0[0:1422],m1[0:1788],m2[0:1998],m3[0:2340];
    reg [11:0] p0,p1,p2,p3,filled;
    reg signed [15:0] a,b,c,d,held;
    reg signed [19:0] lp_a,lp_b,lp_c,lp_d;
    wire signed [21:0] target_a=$signed(a)<<<4,target_b=$signed(b)<<<4,target_c=$signed(c)<<<4,target_d=$signed(d)<<<4;
    wire signed [21:0] next_a=$signed(lp_a)+((target_a-$signed(lp_a))>>>2);
    wire signed [21:0] next_b=$signed(lp_b)+((target_b-$signed(lp_b))>>>2);
    wire signed [21:0] next_c=$signed(lp_c)+((target_c-$signed(lp_c))>>>2);
    wire signed [21:0] next_d=$signed(lp_d)+((target_d-$signed(lp_d))>>>2);
    reg [1:0] state;
    wire signed [18:0] room_sum=$signed(a)+$signed(b)+$signed(c)+$signed(d);
    wire signed [18:0] mixed=$signed(held)-($signed(held)>>>3)+(room_sum>>>3);
    always @(posedge clk) begin
        if(rst)begin p0<=0;p1<=0;p2<=0;p3<=0;filled<=0;state<=0;a<=0;b<=0;c<=0;d<=0;lp_a<=0;lp_b<=0;lp_c<=0;lp_d<=0;held<=0;wet<=0;end
        else case(state)
            0:if(sample_tick)begin
                held<=dry;
                a<=filled>=1423?m0[p0]:16'sd0;b<=filled>=1789?m1[p1]:16'sd0;
                c<=filled>=1999?m2[p2]:16'sd0;d<=filled>=2341?m3[p3]:16'sd0;state<=1;
            end
            1:begin
                lp_a<=enabled?next_a:0;lp_b<=enabled?next_b:0;lp_c<=enabled?next_c:0;lp_d<=enabled?next_d:0;
                m0[p0]<=enabled?($signed(held)>>>4)+(next_a>>>5)+(next_a>>>6):16'sd0;
                m1[p1]<=enabled?($signed(held)>>>4)+(next_b>>>5)+(next_b>>>6):16'sd0;
                m2[p2]<=enabled?($signed(held)>>>4)+(next_c>>>5)+(next_c>>>6):16'sd0;
                m3[p3]<=enabled?($signed(held)>>>4)+(next_d>>>5)+(next_d>>>6):16'sd0;
                if(!enabled)wet<=held;
                else if(mixed>32767)wet<=32767;else if(mixed< -32768)wet<=-32768;else wet<=mixed[15:0];
                p0<=p0==1422?0:p0+1'b1;p1<=p1==1788?0:p1+1'b1;p2<=p2==1998?0:p2+1'b1;p3<=p3==2340?0:p3+1'b1;
                if(filled<2341)filled<=filled+1'b1;state<=0;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
