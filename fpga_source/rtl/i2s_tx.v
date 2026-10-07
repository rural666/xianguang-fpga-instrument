`default_nettype none
// 27 MHz / (2*9*32) = 46875 samples/s, 16-bit stereo, both channels mono.
// Change WS on the final bit of the previous channel (I2S one-bit delay).
module i2s_tx # (parameter integer HALF_DIV=9)(
    input wire clk,input wire rst,input wire signed [15:0] pcm,
    output reg bclk,output reg ws,output reg din,output reg sample_tick
);
    reg [7:0] half_count;
    reg [4:0] bit_pos;
    reg [15:0] held_sample;
    always @(posedge clk) begin
        if(rst) begin
            bclk<=0; ws<=0; din<=0; sample_tick<=0;
            half_count<=0; bit_pos<=0; held_sample<=0;
        end else begin
            sample_tick<=0;
            if(half_count==HALF_DIV-1) begin
                half_count<=0; bclk<=!bclk;
                if(bclk) begin // falling edge, data stable before next rising edge
                    ws<=bit_pos[4];
                    if(bit_pos==0) begin
                        din<=held_sample[0]; held_sample<=pcm; sample_tick<=1;
                    end else if(bit_pos<=16) din<=held_sample[16-bit_pos];
                    else din<=held_sample[32-bit_pos];
                    bit_pos<=bit_pos+1'b1;
                end
            end else half_count<=half_count+1'b1;
        end
    end
endmodule
`default_nettype wire
