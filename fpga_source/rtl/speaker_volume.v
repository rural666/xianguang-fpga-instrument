`default_nettype none
// Q8 gain, smooth 0..100% changes over at most 256 audio samples (5.46 ms).
module speaker_volume(
    input wire clk,rst,sample_tick,input wire [8:0] target,
    input wire signed [15:0] pcm_in,output reg signed [15:0] pcm_out,
    output reg [8:0] applied
);
    wire [8:0] bounded=target>256?9'd256:target;
    reg signed [25:0] product;
    always @(posedge clk)begin
        if(rst)begin applied<=256;product<=0;pcm_out<=0;end
        else begin
            if(sample_tick)begin
                if(applied<bounded)applied<=applied+1'b1;
                else if(applied>bounded)applied<=applied-1'b1;
            end
            product<=pcm_in*$signed({1'b0,applied});
            pcm_out<=product>>>8;
        end
    end
endmodule
`default_nettype wire
