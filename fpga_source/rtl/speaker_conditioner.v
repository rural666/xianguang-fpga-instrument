`default_nettype none
// Small-speaker voicing: two ~237 Hz high-pass stages, gentle low-pass stages,
// then a 64-sample look-ahead level controller. Quiet sounds gain up to 32x;
// strong chords share gain reduction instead of per-sample clipping.
// All processing remains in FPGA. 64/46875 = 1.37 ms look-ahead.
module speaker_conditioner(
    input wire clk,rst,sample_tick,input wire signed [15:0] pcm_in,
    input wire [4:0] voices,
    output reg signed [15:0] pcm_out,output reg limit_fault
);
    // Mix core has 6 dB more headroom. Doubling effective quiet-note gain
    // is paired with slower detector release and lower polyphonic peak level.
    localparam integer CEILING=31000,MAX_GAIN=8192;
    wire [15:0] target_level=voices>1?16'd22000:16'd29000;
    reg signed [25:0] dc,dc2,lp1,lp2;
    wire signed [25:0] x=$signed(pcm_in)*26'sd256;
    wire signed [25:0] hp=x-dc;
    wire signed [25:0] hp2=hp-dc2;
    wire signed [27:0] lp1_delta=$signed(hp2)-$signed(lp1);
    wire signed [27:0] lp2_delta=$signed(lp1)-$signed(lp2);
    wire signed [25:0] out_full=lp2>>>8;
    wire signed [15:0] filtered=out_full>32767?16'sd32767:out_full< -32768?-16'sd32768:out_full[15:0];
    wire [15:0] magnitude=filtered[15] ? -filtered : filtered;
    reg signed [15:0] history[0:63],delayed;
    reg [5:0] pointer;reg [6:0] filled,hold_peak;
    reg [15:0] peak;
    wire [15:0] detected=magnitude>peak?magnitude:peak;
    reg [13:0] gain,target_gain;
    reg [3:0] release_div;
    reg busy;reg [4:0] bit_left;reg [22:0] numerator,quotient;
    reg [15:0] denominator,remainder;
    wire [16:0] trial={remainder,numerator[22]};
    wire subtract=trial>={1'b0,denominator};
    wire [22:0] next_quotient={quotient[21:0],subtract};
    reg signed [30:0] product;
    wire signed [30:0] scaled=product>>>8;
    always @(posedge clk)begin
        if(rst)begin
            dc<=0;dc2<=0;lp1<=0;lp2<=0;pointer<=0;filled<=0;delayed<=0;
            peak<=0;hold_peak<=0;gain<=MAX_GAIN;target_gain<=MAX_GAIN;
            release_div<=0;
            busy<=0;bit_left<=0;numerator<=0;quotient<=0;denominator<=1;remainder<=0;
            product<=0;pcm_out<=0;limit_fault<=0;
        end else begin
            product<=delayed*$signed({1'b0,gain});
            if(scaled>CEILING)begin pcm_out<=CEILING;limit_fault<=1;end
            else if(scaled< -CEILING)begin pcm_out<=-CEILING;limit_fault<=1;end
            else pcm_out<=scaled[15:0];
            if(sample_tick)begin
                dc<=dc+((x-dc)>>>5);
                dc2<=dc2+((hp-dc2)>>>5);
                lp1<=lp1+((lp1_delta+(lp1_delta<<<1))>>>3);
                lp2<=lp2+((lp2_delta+(lp2_delta<<<1))>>>3);
                history[pointer]<=filtered;
                delayed<=filled==64?history[pointer]:16'sd0;
                pointer<=pointer+1'b1;if(filled<64)filled<=filled+1'b1;
                if(magnitude>=peak)begin peak<=magnitude;hold_peak<=96;end
                else if(hold_peak!=0)hold_peak<=hold_peak-1'b1;
                else if(peak>0 && release_div==0)peak<=peak-(peak>>10)-1'b1;
                release_div<=release_div+1'b1;
                // A brief smooth attack finishes well inside the look-ahead.
                if(target_gain<gain)gain<=gain-((gain-target_gain+7)>>3);
                else if(target_gain>gain && release_div==0)gain<=gain+1'b1;
                if(detected<=target_level/32)begin target_gain<=MAX_GAIN;busy<=0;end
                else begin numerator<={target_level[14:0],8'b0};quotient<=0;denominator<=detected;remainder<=0;bit_left<=22;busy<=1;end
            end else if(busy)begin
                numerator<={numerator[21:0],1'b0};quotient<=next_quotient;
                remainder<=subtract ? trial-denominator : trial;
                if(bit_left==0)begin target_gain<=next_quotient>MAX_GAIN?MAX_GAIN:next_quotient[13:0];busy<=0;end
                else bit_left<=bit_left-1'b1;
            end
        end
    end
endmodule
`default_nettype wire
