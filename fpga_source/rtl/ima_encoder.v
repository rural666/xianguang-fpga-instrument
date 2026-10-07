`default_nettype none
// IMA 4-bit ADPCM, shift/add reconstruction (same integer rounding as IMA WAV).
module ima_encoder(input wire clk,rst,start,input wire signed [15:0] sample,
    output reg done,output reg [3:0] code,output reg signed [15:0] predictor,output reg [6:0] step_index);
    reg [15:0] steps[0:88];
    reg signed [15:0] held;
    reg [15:0] step;
    reg busy;
    integer magnitude,difference,decoded,next_predictor,next_index;
    reg [3:0] nibble;
    initial $readmemh("rtl/ima_steps.hex",steps);
    always @* begin
        difference=$signed(held)-$signed(predictor);nibble=0;
        if(difference<0)begin nibble=8;magnitude=-difference;end else magnitude=difference;
        decoded=step>>3;
        if(magnitude>=step)begin nibble=nibble|4;magnitude=magnitude-step;decoded=decoded+step;end
        if(magnitude>=(step>>1))begin nibble=nibble|2;magnitude=magnitude-(step>>1);decoded=decoded+(step>>1);end
        if(magnitude>=(step>>2))begin nibble=nibble|1;decoded=decoded+(step>>2);end
        next_predictor=nibble[3]?$signed(predictor)-decoded:$signed(predictor)+decoded;
        if(next_predictor>32767)next_predictor=32767;else if(next_predictor< -32768)next_predictor=-32768;
        case(nibble[2:0])
            0,1,2,3:next_index=step_index-1;4:next_index=step_index+2;
            5:next_index=step_index+4;6:next_index=step_index+6;7:next_index=step_index+8;
            default:next_index=0;
        endcase
        if(next_index<0)next_index=0;else if(next_index>88)next_index=88;
    end
    always @(posedge clk)begin
        if(rst)begin done<=0;code<=0;predictor<=0;step_index<=0;held<=0;step<=7;busy<=0;end
        else begin
            done<=0;
            if(start && !busy)begin held<=sample;step<=steps[step_index];busy<=1;end
            else if(busy)begin predictor<=next_predictor[15:0];step_index<=next_index[6:0];code<=nibble;done<=1;busy<=0;end
        end
    end
endmodule
`default_nettype wire
