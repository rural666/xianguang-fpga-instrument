`default_nettype none
module encoder_control #(
    parameter integer AB_FILTER=2700, SW_FILTER=270000
)(
    input wire clk,rst, input wire enc_a,enc_b,enc_sw,
    output reg step_up,step_down,press,
    output reg signed [31:0] position, output reg [15:0] presses,
    output wire [2:0] stable_pins
);
    reg [2:0] meta,sync;
    reg [1:0] ab,previous_ab,ab_candidate;
    reg sw;
    reg [31:0] ab_count,sw_count;
    reg signed [3:0] quarters;
    reg signed [3:0] delta;
    wire signed [4:0] next_quarters=quarters+delta;
    assign stable_pins={ab,sw};
    always @* begin
        case({previous_ab,ab})
            4'b1101,4'b0100,4'b0010,4'b1011:delta=1;
            4'b1110,4'b1000,4'b0001,4'b0111:delta=-1;
            default:delta=0;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            meta<=7;sync<=7;ab<=3;previous_ab<=3;ab_candidate<=3;sw<=1;ab_count<=0;sw_count<=0;
            quarters<=0;step_up<=0;step_down<=0;press<=0;position<=0;presses<=0;
        end else begin
            meta<={enc_a,enc_b,enc_sw};sync<=meta;
            step_up<=0;step_down<=0;press<=0;
            if(sync[2:1]!=ab_candidate)begin ab_candidate<=sync[2:1];ab_count<=0;end
            else if(ab_candidate==ab) ab_count<=0;
            else if(ab_count==AB_FILTER-1) begin ab<=ab_candidate;ab_count<=0;end
            else ab_count<=ab_count+1'b1;
            if(sync[0]==sw) sw_count<=0;
            else if(sw_count==SW_FILTER-1) begin
                sw<=sync[0];sw_count<=0;
                if(!sync[0]) begin press<=1;presses<=presses+1'b1;end
            end else sw_count<=sw_count+1'b1;
            previous_ab<=ab;
            if(ab!=previous_ab) begin
                if(delta==0) quarters<=0; // reject illegal two-bit transitions
                else if(ab==2'b11) begin
                    quarters<=0;
                    if(next_quarters>=4) begin step_up<=1;position<=position+1'b1;end
                    else if(next_quarters<=-4) begin step_down<=1;position<=position-1'b1;end
                end else quarters<=next_quarters[3:0];
            end
        end
    end
endmodule
`default_nettype wire
