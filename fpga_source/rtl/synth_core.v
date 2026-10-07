`default_nettype none
// Two independent chromatic octaves, 24 hardware voices. The time-multiplexed
// oscillator takes 481 clocks per frame, below the 576-clock sample period.
module synth_core #(parameter integer MASTER_SHIFT=3,LINEAR_MIX=0)(
    input wire clk,rst,sample_tick,input wire [23:0] keys,
    input wire [2:0] timbre,input wire sustain,input wire [1:0] octave,
    input wire [6:0] vibrato_depth,
    output reg signed [15:0] pcm,output reg active,overrun,output reg [4:0] voice_count
);
    reg [31:0] phase[0:23],phase_pair[0:23],phase_third[0:23],note_step[0:23];
    reg [23:0] envelope[0:23],brightness[0:23],hammer[0:23];
    reg [2:0] env_state[0:23];
    reg [23:0] prev_keys,frame_keys;
    reg [2:0] frame_timbre;
    reg frame_sustain,new_attack;
    reg [1:0] frame_octave;
    reg [4:0] voice,frame_count;reg [4:0] state;
    reg [31:0] p,pair_p,third_p,base_step,lfo_phase;
    reg signed [15:0] vibrato_product;
    wire signed [7:0] vibrato_level=vibrato_product>>>7;
    wire signed [28:0] pitch_offset=$signed({1'b0,base_step[31:12]})*vibrato_level;
    wire signed [31:0] pitch_adjustment=pitch_offset>>>1;
    reg [10:0] rom_addr;
    reg [11:0] rom_fraction;
    reg signed [15:0] rom[0:2047];
    reg signed [15:0] rom_base,rom_next;reg [11:0] rom_fraction_d;
    always @(posedge clk)begin rom_base<=rom[rom_addr];rom_next<=rom[rom_addr+11'd1];rom_fraction_d<=rom_fraction;end
    wire signed [16:0] rom_delta=$signed({rom_next[15],rom_next})-$signed({rom_base[15],rom_base});
    wire signed [29:0] rom_slope=rom_delta*$signed({1'b0,rom_fraction_d});
    wire signed [16:0] rom_interpolated=$signed({rom_base[15],rom_base})+(rom_slope>>>12);
    reg signed [15:0] w1,w2,w3,w4,w5,w6,wd,wt;
    reg signed [17:0] wave;
    reg [15:0] gain,bright_gain,hammer_gain;
    reg signed [32:0] harmonic_product,hammer_product;
    reg signed [34:0] product;
    reg signed [23:0] sum;
    wire signed [23:0] contribution=product>>>16;
    wire signed [23:0] total=sum+contribution;
    wire signed [23:0] scaled=total>>>MASTER_SHIFT;
    wire [23:0] magnitude=scaled[23] ? -scaled : scaled;
    wire [23:0] limited=LINEAR_MIX ? magnitude : magnitude>24576 ? 24'd24576+((magnitude-24576)>>2) : magnitude;
    wire signed [15:0] triangle=p[31] ? $signed({~p[30:16],1'b0})-16'sd32767 : $signed({p[30:16],1'b0})-16'sd32767;
    wire [31:0] p2=p<<1,p3=p+(p<<1),p4=p<<2,p5=p+(p<<2),p6=(p<<1)+(p<<2);
    wire signed [15:0] harmonics=frame_timbre==1 ?
        (w2>>>2)+(w3>>>4) : (w2>>>3)+(w3>>>5);
    wire signed [15:0] hammer_harmonics=frame_timbre==1 ?
        (w3>>>4)+(w4>>>5)+(w5>>>5)+(w6>>>6) :
        (w3>>>5)+(w4>>>5)+(w5>>>6)+(w6>>>7);
    wire [16:0] brilliance={1'b0,bright_gain};
    integer i;
    initial $readmemh("rtl/sine2048.hex",rom);
    // Only power-on initialization is needed: this instrument's rst is the
    // FPGA power-on reset. Avoid resetting every voice word in parallel so
    // the arrays can map to the device's memory resources.
    initial for(i=0;i<24;i=i+1) begin
        phase[i]=0; phase_pair[i]=0; phase_third[i]=0;
        note_step[i]=i<12 ? phase_step(i) : phase_step(i-12)<<1;
        envelope[i]=0; brightness[i]=0; hammer[i]=0; env_state[i]=0;
    end
    function [31:0] phase_step;
        input [3:0] n;
        begin case(n)
            0:phase_step=23971696;1:phase_step=25397127;2:phase_step=26907319;3:phase_step=28507311;
            4:phase_step=30202444;5:phase_step=31998375;6:phase_step=33901097;7:phase_step=35916962;
            8:phase_step=38052695;9:phase_step=40315426;10:phase_step=42712706;default:phase_step=45252536;
        endcase end
    endfunction
    wire [3:0] note_class=voice>=12 ? voice-5'd12 : voice[3:0];
    wire [31:0] chromatic_step=phase_step(note_class);
    wire [31:0] current_step=frame_octave==0 ? (voice>=12 ? chromatic_step : chromatic_step>>1) :
                             frame_octave==2 ? (voice>=12 ? chromatic_step<<2 : chromatic_step<<1) :
                                                (voice>=12 ? chromatic_step<<1 : chromatic_step);
    always @(posedge clk) begin
        if(rst) begin
            prev_keys<=0;frame_keys<=0;frame_timbre<=0;frame_sustain<=0;frame_octave<=1;new_attack<=0;
            voice<=0;state<=0;frame_count<=0;voice_count<=0;p<=0;pair_p<=0;third_p<=0;base_step<=0;lfo_phase<=0;vibrato_product<=0;
            rom_addr<=0;rom_fraction<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;wd<=0;wt<=0;wave<=0;gain<=0;bright_gain<=0;hammer_gain<=0;
            harmonic_product<=0;hammer_product<=0;product<=0;sum<=0;pcm<=0;active<=0;overrun<=0;
        end else begin
            if(sample_tick && state!=0)overrun<=1;
            case(state)
                0:if(sample_tick)begin
                    frame_keys<=keys;frame_timbre<=timbre;frame_sustain<=sustain;frame_octave<=octave;
                    sum<=0;voice<=0;frame_count<=0;lfo_phase<=lfo_phase+32'd503943;
                    vibrato_product<=$signed(rom[lfo_phase[31:21]][15:8])*$signed({1'b0,vibrato_depth});state<=1;
                end
                1:begin
                    p<=phase[voice];pair_p<=phase_pair[voice];third_p<=phase_third[voice];base_step<=note_step[voice];rom_addr<=phase[voice][31:21];rom_fraction<=phase[voice][20:9];
                    gain<=envelope[voice][23:8];bright_gain<=brightness[voice][23:8];hammer_gain<=hammer[voice][23:8];
                    new_attack<=frame_keys[voice] && !prev_keys[voice];prev_keys[voice]<=frame_keys[voice];
                    if(envelope[voice]!=0 || frame_keys[voice])frame_count<=frame_count+1'b1;
                    // Smooth excitation even when a key is retriggered before its tail ends.
                    if(env_state[voice]==1)begin
                        brightness[voice]<=brightness[voice]+((24'hffffff-brightness[voice])>>5);
                        hammer[voice]<=hammer[voice]+((24'hffffff-hammer[voice])>>5);
                    end else begin
                        if(brightness[voice]>4096)brightness[voice]<=brightness[voice]-(brightness[voice]>>14)-1'b1;else brightness[voice]<=0;
                        if(hammer[voice]>4096)hammer[voice]<=hammer[voice]-(hammer[voice]>>12)-1'b1;else hammer[voice]<=0;
                    end
                    if(frame_keys[voice] && !prev_keys[voice])begin
                        env_state[voice]<=1;note_step[voice]<=current_step;
                    end else if(!frame_keys[voice] && !frame_sustain && env_state[voice]!=0 && env_state[voice]!=4)env_state[voice]<=4;
                    else case(env_state[voice])
                        0:envelope[voice]<=0;
                        1:if(envelope[voice]>=24'hfeffff)begin envelope[voice]<=24'hffffff;env_state[voice]<=2;end
                          else envelope[voice]<=envelope[voice]+24'd65536;
                        2:if(frame_timbre<2)begin
                            if(envelope[voice]<512)begin envelope[voice]<=0;env_state[voice]<=0;end
                            else if(envelope[voice]>24'h780000)envelope[voice]<=envelope[voice]-(envelope[voice]>>13)-1'b1;
                            else envelope[voice]<=envelope[voice]-(envelope[voice]>>(frame_timbre==0?17:16))-1'b1;
                          end else if(envelope[voice]<=24'hb00000)begin envelope[voice]<=24'hb00000;env_state[voice]<=3;end
                          else envelope[voice]<=envelope[voice]-(envelope[voice]>>12)-1'b1;
                        3:envelope[voice]<=24'hb00000;
                        4:if(envelope[voice]<=512)begin envelope[voice]<=0;env_state[voice]<=0;end
                          else envelope[voice]<=envelope[voice]-(envelope[voice]>>(frame_timbre<2?12:11))-24'd32;
                        default:begin envelope[voice]<=0;env_state[voice]<=0;end
                    endcase
                    state<=2;
                end
                2:begin
                    if(new_attack && gain==0)begin phase[voice]<=0;phase_pair[voice]<=0;phase_third[voice]<=0;end
                    else begin
                        phase[voice]<=p+base_step+$signed(pitch_adjustment);
                        phase_pair[voice]<=pair_p+base_step+(base_step>>12)+$signed(pitch_adjustment);
                        phase_third[voice]<=third_p+base_step-(base_step>>12)+$signed(pitch_adjustment);
                    end
                    state<=3;
                end
                3:begin w1<=rom_interpolated;rom_addr<=p2[31:21];rom_fraction<=p2[20:9];state<=4;end
                4:state<=5;
                5:begin w2<=rom_interpolated;rom_addr<=p3[31:21];rom_fraction<=p3[20:9];state<=6;end
                6:state<=7;
                7:begin w3<=rom_interpolated;rom_addr<=p4[31:21];rom_fraction<=p4[20:9];state<=8;end
                8:state<=9;
                9:begin w4<=rom_interpolated;rom_addr<=p5[31:21];rom_fraction<=p5[20:9];state<=10;end
                10:state<=11;
                11:begin w5<=rom_interpolated;rom_addr<=p6[31:21];rom_fraction<=p6[20:9];state<=12;end
                12:state<=13;
                13:begin w6<=rom_interpolated;rom_addr<=pair_p[31:21];rom_fraction<=pair_p[20:9];state<=14;end
                14:state<=15;
                15:begin wd<=rom_interpolated;rom_addr<=third_p[31:21];rom_fraction<=third_p[20:9];state<=16;end
                16:state<=17;
                17:begin wt<=rom_interpolated;harmonic_product<=harmonics*$signed(brilliance);hammer_product<=hammer_harmonics*$signed({1'b0,hammer_gain});state<=18;end
                18:begin
                    case(frame_timbre)
                        0:wave<=($signed(w1)>>>1)+($signed(wd)>>>3)+($signed(wt)>>>3)+(harmonic_product>>>16)+(hammer_product>>>16);
                        1:wave<=($signed(w1)>>>1)+($signed(wd)>>>3)+($signed(wt)>>>4)+(harmonic_product>>>16)+(hammer_product>>>16);
                        2:wave<=w1;
                        3:wave<=triangle;
                        4:wave<=($signed(w1)>>>1)+($signed(w2)>>>2)+($signed(w3)>>>3);
                        5:wave<=($signed(w1)>>>1)+($signed(w3)>>>2)+($signed(w5)>>>3);
                        6:wave<=($signed(w1)>>>1)+($signed(w3)>>>3)+($signed(w5)>>>4);
                        7:wave<=($signed(w1)>>>1)-($signed(w2)>>>2)+($signed(w3)>>>3)-($signed(w4)>>>4)+($signed(w5)>>>5)-($signed(w6)>>>5);
                    endcase state<=19;
                end
                19:begin product<=wave*$signed({1'b0,gain});state<=20;end
                20:if(voice==23)begin
                    if(limited>32767)pcm<=scaled[23]?-16'sd32767:16'sd32767;
                    else pcm<=scaled[23]?-$signed(limited[15:0]):$signed(limited[15:0]);
                    active<=frame_count!=0;voice_count<=frame_count;state<=0;
                end else begin sum<=total;voice<=voice+1'b1;state<=1;end
                default:state<=0;
            endcase
        end
    end
endmodule
`default_nettype wire
