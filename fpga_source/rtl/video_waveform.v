`default_nettype none
// Two audio-history banks. The 27 MHz side writes a decimated, rolling
// 512-sample view of the actual speaker PCM. At vertical blank the completed
// bank is published; the pixel side reads it for the whole next frame.
module video_waveform(
    input wire sys_clk,pix_clk,sys_reset,pix_reset,frame_blank,
    input wire sample_tick,input wire signed [15:0] pcm,
    input wire [10:0] video_x,
    output reg signed [7:0] sample=0
);
    reg [7:0] bank0[0:511],bank1[0:511];
    integer i;
    initial for(i=0;i<512;i=i+1)begin bank0[i]=0;bank1[i]=0;end
    reg write_bank=0,published_bank=0;
    reg [8:0] write_ptr=0,published_start=0;
    reg [1:0] decim=0;
    reg request=0,sys_ack=0,pix_ack=0;
    reg [2:0] request_sync=0,ack_sync=0;
    reg read_bank=0;
    reg [8:0] read_start=0;
    wire [8:0] read_addr=read_start+video_x[8:0]-9'd64;
    always @(posedge sys_clk)begin
        request_sync<={request_sync[1:0],request};
        if(sys_reset)begin
            write_bank<=0;write_ptr<=0;decim<=0;
            published_bank<=0;published_start<=0;sys_ack<=0;
        end else if(request_sync[2]!=sys_ack)begin
            published_bank<=write_bank;
            published_start<=write_ptr;
            write_bank<=~write_bank;
            write_ptr<=0;decim<=0;sys_ack<=request_sync[2];
        end else if(sample_tick)begin
            decim<=decim==2?2'd0:decim+1'b1;
            if(decim!=2)begin
                if(write_bank)bank1[write_ptr]<=pcm[15:8];
                else bank0[write_ptr]<=pcm[15:8];
                write_ptr<=write_ptr+1'b1;
            end
        end
    end
    always @(posedge pix_clk)begin
        ack_sync<={ack_sync[1:0],sys_ack};
        if(pix_reset)begin
            request<=0;pix_ack<=0;read_bank<=0;read_start<=0;sample<=0;
        end else begin
            if(frame_blank && request==ack_sync[2])request<=~request;
            if(ack_sync[2]==request && ack_sync[2]!=pix_ack)begin
                read_bank<=published_bank;
                read_start<=published_start;
                pix_ack<=ack_sync[2];
            end
            if(read_bank)sample<=bank1[read_addr];
            else sample<=bank0[read_addr];
        end
    end
endmodule
`default_nettype wire
