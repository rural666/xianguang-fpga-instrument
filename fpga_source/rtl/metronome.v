`default_nettype none
// Sample-clock metronome. Accumulating BPM against 60*46875 avoids a large
// variable divider and keeps the long-term beat rate exact at integer BPM.
module metronome(
    input wire clk,rst,sample_tick,input wire [7:0] bpm,
    output reg signed [15:0] click,output reg flash
);
    localparam [21:0] MINUTE_SAMPLES=22'd2812500;
    reg [21:0] phase=0;
    reg [9:0] click_left=0;
    reg [11:0] flash_left=0;
    reg [4:0] tone_div=0;
    reg tone=0,was_enabled=0,accent=0;
    reg [1:0] beat=0;
    wire [22:0] next_phase={1'b0,phase}+{15'b0,bpm};
    always @(posedge clk)begin
        if(rst)begin
            phase<=0;click_left<=0;flash_left<=0;tone_div<=0;
            tone<=0;was_enabled<=0;accent<=0;beat<=0;click<=0;flash<=0;
        end else if(sample_tick)begin
            was_enabled<=bpm!=0;
            if(bpm==0)begin
                phase<=0;click_left<=0;flash_left<=0;beat<=0;
                click<=0;flash<=0;
            end else begin
                if(!was_enabled || next_phase>=MINUTE_SAMPLES)begin
                    phase<=!was_enabled ? 0 : next_phase-MINUTE_SAMPLES;
                    click_left<=10'd700;flash_left<=12'd3750;
                    flash<=1;accent<=beat==0;beat<=beat+1'b1;
                    tone_div<=0;tone<=0;click<=beat==0 ? 16'sd2200 : 16'sd1400;
                end else begin
                    phase<=next_phase[21:0];
                    if(flash_left!=0)flash_left<=flash_left-1'b1;
                    else flash<=0;
                    if(click_left!=0)begin
                        click_left<=click_left-1'b1;
                        if(tone_div==5'd23)begin tone_div<=0;tone<=~tone;end
                        else tone_div<=tone_div+1'b1;
                        click<=tone ? (accent ? -16'sd2200 : -16'sd1400) :
                                      (accent ? 16'sd2200 : 16'sd1400);
                    end else click<=0;
                end
            end
        end
    end
endmodule
`default_nettype wire
