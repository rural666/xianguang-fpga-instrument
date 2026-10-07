`default_nettype none
// 122-byte independently decodable ADPCM6 packets; 128 samples at 23437.5 Hz.
// UART remains 230400. Header reports 46875 Hz after deterministic 2x interpolation.
module audio_uart_stream(input wire clk,rst,sample_tick,input wire signed [15:0] pcm,
    input wire [7:0] flags,input wire [15:0] expression_meta,input wire [11:0] keys,
    input wire [2:0] timbre,input wire [3:0] voices,input wire [1:0] octave,
    input wire room,input wire [6:0] vibrato_depth,output wire tx,output reg overflow);
    reg [15:0] fifo[0:1023];reg [10:0] wr_ptr,rd_ptr;
    wire full=(wr_ptr[10]!=rd_ptr[10]) && (wr_ptr[9:0]==rd_ptr[9:0]);
    wire [10:0] used=wr_ptr-rd_ptr;
    reg [15:0] crc,seq_counter,snap_sequence,snap_meta,snap_keys,snap_predictor;
    reg [7:0] snap_flags,snap_timbre,snap_voices,snap_index,snap_depth;
    reg [6:0] byte_index;reg [3:0] state;reg [1:0] code_index,payload_lane;
    reg [23:0] packed_codes;
    reg tx_start,encode_start;reg [7:0] tx_data;reg signed [15:0] encode_sample;
    wire tx_busy,encode_done;wire [5:0] code;wire signed [15:0] predictor;wire [6:0] step_index;
    uart_tx #(.BAUD(230400)) u_tx(.clk(clk),.rst(rst),.start(tx_start),.data(tx_data),.tx(tx),.busy(tx_busy));
    adpcm6_encoder encoder(.clk(clk),.rst(rst),.start(encode_start),.sample(encode_sample),.done(encode_done),.code(code),.predictor(predictor),.step_index(step_index));
    function [15:0] crc_byte;
        input [15:0] old;input [7:0] data;reg [15:0] c;integer k;
        begin c=old^{data,8'b0};for(k=0;k<8;k=k+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc_byte=c;end
    endfunction
    function [7:0] header;
        input [6:0] index;
        begin case(index)
            0:header="T";1:header="2";2:header="0";3:header="A";4:header=4;5:header=snap_flags;
            6:header=snap_sequence[7:0];7:header=snap_sequence[15:8];
            8:header=8'h1b;9:header=8'hb7;10:header=0;11:header=0;
            12:header=128;13:header=0;14:header=snap_meta[7:0];15:header=snap_meta[15:8];
            16:header=snap_keys[7:0];17:header=snap_keys[15:8];18:header=snap_timbre;19:header=snap_voices;
            20:header=snap_predictor[7:0];21:header=snap_predictor[15:8];22:header=snap_index;23:header=snap_depth;
            default:header=0;
        endcase end
    endfunction
    always @(posedge clk)begin
        if(rst)begin wr_ptr<=0;overflow<=0;end
        else if(sample_tick)begin
            if(!full)begin fifo[wr_ptr[9:0]]<=pcm;wr_ptr<=wr_ptr+1'b1;end else overflow<=1;
        end
    end
    always @(posedge clk)begin
        if(rst)begin
            rd_ptr<=0;crc<=16'hffff;seq_counter<=0;snap_sequence<=0;snap_meta<=0;snap_keys<=0;snap_predictor<=0;
            snap_flags<=0;snap_timbre<=0;snap_voices<=0;snap_index<=0;snap_depth<=0;
            byte_index<=0;state<=0;code_index<=0;payload_lane<=0;packed_codes<=0;tx_start<=0;encode_start<=0;tx_data<=0;encode_sample<=0;
        end else begin
            tx_start<=0;encode_start<=0;
            case(state)
                0:if(used>=128)begin
                    snap_sequence<=seq_counter;seq_counter<=seq_counter+1'b1;snap_meta<=expression_meta;
                    snap_keys<={2'b0,octave,keys};snap_predictor<=predictor;snap_index<={1'b0,step_index};
                    snap_flags<=flags|{6'b0,overflow,1'b0};snap_timbre<={3'b0,room,1'b0,timbre};
                    snap_voices<={4'b0,voices};snap_depth<={1'b0,vibrato_depth};
                    byte_index<=0;payload_lane<=0;crc<=16'hffff;state<=1;
                end
                1:if(!tx_busy)begin
                    if(byte_index<24)begin tx_data<=header(byte_index);tx_start<=1;state<=8;end
                    else if(byte_index<120)begin
                        if(payload_lane==0)begin code_index<=0;encode_sample<=fifo[rd_ptr[9:0]];state<=2;end
                        else begin tx_data<=payload_lane==1?packed_codes[15:8]:packed_codes[23:16];tx_start<=1;state<=8;end
                    end
                    else begin tx_data<=byte_index==120?crc[7:0]:crc[15:8];tx_start<=1;state<=8;end
                end
                2:begin encode_start<=1;state<=3;end
                3:if(encode_done)begin
                    packed_codes[code_index*6+:6]<=code;rd_ptr<=rd_ptr+1'b1;
                    if(code_index==3)state<=4;else begin code_index<=code_index+1'b1;state<=5;end
                end
                4:begin tx_data<=packed_codes[7:0];tx_start<=1;state<=8;end
                5:begin encode_sample<=fifo[rd_ptr[9:0]];state<=2;end
                8:state<=9;
                9:if(!tx_busy)begin
                    if(byte_index>=4 && byte_index<120)crc<=crc_byte(crc,tx_data);
                    if(byte_index>=24 && byte_index<120)payload_lane<=payload_lane==2?0:payload_lane+1'b1;
                    if(byte_index==121)state<=0;else begin byte_index<=byte_index+1'b1;state<=1;end
                end
                default:state<=0;
            endcase
        end
    end
endmodule
`default_nettype wire

