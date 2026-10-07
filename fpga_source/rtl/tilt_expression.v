`default_nettype none
// Relative acceleration-vector displacement, not a fused orientation angle.
// Both forward/back and left/right tilt reduce gain from 1.0 to 0.125.
// Capture a neutral vector only after 16 stable, distinct sensor samples.
module tilt_expression(
    input wire clk,rst,sample_tick,sample_valid,enabled,online,calibrate,
    input wire lock_volume,unlock_volume,reset_volume,
    input wire signed [15:0] ax,ay,az,pcm_in,
    output reg signed [15:0] pcm_out,output reg [8:0] gain,
    output reg calibrated,output wire calibrating,output reg locked
);
    reg [5:0] divider;
    reg [8:0] locked_gain;
    reg signed [15:0] baseline_x,baseline_y,baseline_z;
    reg signed [15:0] anchor_x,anchor_y,anchor_z;
    reg signed [19:0] sum_x,sum_y,sum_z;
    reg [4:0] stable_count;
    reg previous_enabled,previous_online;
    function [16:0] absolute;
        input signed [16:0] value;
        begin absolute=value[16] ? -value : value; end
    endfunction
    wire [16:0] dx=absolute($signed({ax[15],ax})-$signed({baseline_x[15],baseline_x}));
    wire [16:0] dy=absolute($signed({ay[15],ay})-$signed({baseline_y[15],baseline_y}));
    wire [16:0] dz=absolute($signed({az[15],az})-$signed({baseline_z[15],baseline_z}));
    wire [16:0] max_xy=dx>dy ? dx : dy;
    wire [16:0] displacement=max_xy>dz ? max_xy : dz;
    wire [16:0] excess=displacement>256 ? displacement-17'd256 : 17'd0;
    wire signed [17:0] requested=18'sd256-$signed({1'b0,(excess>>6)});
    wire [8:0] target=locked ? locked_gain : (!enabled||!online||!calibrated) ? 9'd256 :
        (requested<32 ? 9'd32 : requested[8:0]);
    wire [16:0] anchor_dx=absolute($signed({ax[15],ax})-$signed({anchor_x[15],anchor_x}));
    wire [16:0] anchor_dy=absolute($signed({ay[15],ay})-$signed({anchor_y[15],anchor_y}));
    wire [16:0] anchor_dz=absolute($signed({az[15],az})-$signed({anchor_z[15],anchor_z}));
    wire signed [19:0] total_x=sum_x+{{4{ax[15]}},ax};
    wire signed [19:0] total_y=sum_y+{{4{ay[15]}},ay};
    wire signed [19:0] total_z=sum_z+{{4{az[15]}},az};
    wire signed [25:0] product=pcm_in*$signed({1'b0,gain});
    assign calibrating=enabled && online && !calibrated;
    always @(posedge clk) begin
        if(rst) begin
            divider<=0;gain<=256;locked<=1;locked_gain<=256;pcm_out<=0;calibrated<=0;stable_count<=0;
            baseline_x<=0;baseline_y<=0;baseline_z<=0;anchor_x<=0;anchor_y<=0;anchor_z<=0;
            sum_x<=0;sum_y<=0;sum_z<=0;previous_enabled<=0;previous_online<=0;
        end else begin
            previous_enabled<=enabled;previous_online<=online;
            if(lock_volume)begin locked<=1;locked_gain<=gain;end
            if(unlock_volume)locked<=0;
            if(reset_volume)begin locked<=1;locked_gain<=256;end
            if(!enabled || !online || calibrate || !previous_enabled || !previous_online) begin
                calibrated<=0;stable_count<=0;
            end else if(sample_valid && !calibrated) begin
                if(stable_count==0 || anchor_dx>512 || anchor_dy>512 || anchor_dz>512) begin
                    anchor_x<=ax;anchor_y<=ay;anchor_z<=az;stable_count<=1;
                    sum_x<={{4{ax[15]}},ax};sum_y<={{4{ay[15]}},ay};sum_z<={{4{az[15]}},az};
                end else if(stable_count==15) begin
                    baseline_x<=total_x>>>4;baseline_y<=total_y>>>4;baseline_z<=total_z>>>4;
                    calibrated<=1;stable_count<=0;
                end else begin
                    sum_x<=total_x;sum_y<=total_y;sum_z<=total_z;stable_count<=stable_count+1'b1;
                end
            end
            pcm_out<=product>>>8;
            if(sample_tick) begin
                divider<=divider+1'b1;
                if(divider==0) begin
                    if(gain<target)gain<=gain+1'b1;
                    else if(gain>target)gain<=gain-1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
