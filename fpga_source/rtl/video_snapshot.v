`default_nettype none
// One stable instrument-state snapshot per video frame. Handshake keeps the
// multibit bus fixed across the 27 MHz / 74.25 MHz clock boundary.
module video_snapshot(
    input wire sys_clk,pix_clk,sys_reset,pix_reset,frame_blank,
    input wire [23:0] keys,input wire [2:0] timbre,
    input wire [4:0] voices,input wire [8:0] volume,
    input wire [1:0] octave,input wire [7:0] flags,
    input wire [7:0] bpm,input wire beat,input wire [7:0] song_status,input wire [7:0] usb_diag,
    input wire signed [15:0] pcm,input wire sample_tick,
    output reg [23:0] v_keys,output reg [2:0] v_timbre,
    output reg [4:0] v_voices,output reg [8:0] v_volume,
    output reg [1:0] v_octave,output reg [7:0] v_flags,
    output reg [7:0] v_bpm,output reg v_beat,output reg [7:0] v_song_status,output reg [7:0] v_usb_diag,
    output reg [7:0] v_peak
);
    reg request=0,ack=0,accepted=0;
    reg [2:0] request_sync=0,ack_sync=0;
    reg [83:0] capture=0;
    reg [7:0] peak=0;
    wire [15:0] magnitude=pcm[15]?-pcm:pcm;
    wire [7:0] level=(pcm==16'h8000)?8'hff:magnitude[14:7];
    always @(posedge sys_clk)begin
        request_sync<={request_sync[1:0],request};
        if(sys_reset)begin ack<=0;capture<=0;peak<=0;end
        else begin
            if(request_sync[2]!=ack)begin
                capture<={keys,timbre,voices,volume,octave,flags,bpm,beat,song_status,usb_diag,peak};
                ack<=request_sync[2];peak<=0;
            end else if(sample_tick && level>peak)peak<=level;
        end
    end
    always @(posedge pix_clk)begin
        ack_sync<={ack_sync[1:0],ack};
        if(pix_reset)begin
            request<=0;accepted<=0;v_keys<=0;v_timbre<=0;v_voices<=0;
            v_volume<=256;v_octave<=1;v_flags<=0;v_bpm<=0;v_beat<=0;v_song_status<=0;v_usb_diag<=0;v_peak<=0;
        end else begin
            if(frame_blank && request==ack_sync[2])request<=~request;
            if(ack_sync[2]==request && ack_sync[2]!=accepted)begin
                {v_keys,v_timbre,v_voices,v_volume,v_octave,v_flags,v_bpm,v_beat,v_song_status,v_usb_diag,v_peak}<=capture;
                accepted<=ack_sync[2];
            end
        end
    end
endmodule
`default_nettype wire
