`default_nettype none
// One row with two octaves. All motion follows the same 24 note states
// used by the synthesizer; the gold trace uses actual speaker PCM history.
module studio_scene(
    input wire clk,reset,frame_blank,
    input wire [10:0] video_x,input wire [9:0] video_y,
    input wire [23:0] keys,input wire [2:0] timbre,
    input wire [4:0] voices,input wire [8:0] volume,
    input wire [1:0] octave,input wire [7:0] flags,input wire [7:0] peak,
    input wire [7:0] bpm,input wire beat,input wire [7:0] song_status,input wire [7:0] usb_diag,
    input wire signed [7:0] waveform,
    output reg [23:0] rgb=24'h0c0b0a
);
    wire [9:0] x=video_x[9:0];
    wire [8:0] y=video_y[8:0];
    reg [7:0] heat[0:23];
    reg [2:0] travel[0:23];
    integer i;
    initial for(i=0;i<24;i=i+1)begin heat[i]=0;travel[i]=0;end
    always @(posedge clk)begin
        if(reset)begin
            for(i=0;i<24;i=i+1)begin heat[i]<=0;travel[i]<=0;end
        end else if(frame_blank)begin
            for(i=0;i<24;i=i+1)begin
                if(keys[i])begin
                    heat[i]<=255;
                    if(travel[i]<4)travel[i]<=travel[i]+1'b1;
                end else begin
                    heat[i]<=heat[i]<=16?8'd0:heat[i]-8'd16;
                    if(travel[i]!=0)travel[i]<=travel[i]-1'b1;
                end
            end
        end
    end
    function [4:0] white_note;
        input [3:0] n;
        reg [3:0] c;
        begin
            c=n>=7?n-7:n;
            case(c)
                0:white_note=0;1:white_note=2;2:white_note=4;3:white_note=5;
                4:white_note=7;5:white_note=9;default:white_note=11;
            endcase
            if(n>=7)white_note=white_note+12;
        end
    endfunction
    function [4:0] black_note;
        input [3:0] n;
        reg [3:0] c;
        begin
            c=n>=5?n-5:n;
            case(c)
                0:black_note=1;1:black_note=3;2:black_note=6;
                3:black_note=8;default:black_note=10;
            endcase
            if(n>=5)black_note=black_note+12;
        end
    endfunction
    function [9:0] black_x;
        input [3:0] n;
        reg [3:0] c;
        begin
            c=n>=5?n-5:n;
            case(c)
                0:black_x=68;1:black_x=108;2:black_x=188;
                3:black_x=228;default:black_x=268;
            endcase
            if(n>=5)black_x=black_x+280;
        end
    endfunction
    wire [8:0] row_top=9'd256;
    wire signed [9:0] wave_y=10'sd207+($signed(waveform)>>>2);
    reg [23:0] scene;
    reg [9:0] left;
    reg [4:0] note;
    reg [2:0] drop,label_drop;
    reg [8:0] face_bottom;
    reg black_area,key_area;
    integer j;
    always @*begin
        scene=24'h0c0b0a;
        left=0;note=0;drop=0;label_drop=0;face_bottom=0;
        black_area=0;key_area=0;
        if(x>=24 && x<616 && (y==124 || y==433))scene=24'h30271e;
        if(x>=64 && x<576 && y>=174 && y<=240)begin
            if(y==207)scene=24'h342c20;
            if(peak>4 && (y+2==wave_y || y==wave_y+2))scene=24'h4b3b24;
            if(peak>4 && (y+1==wave_y || y==wave_y+1))scene=24'h9c7c46;
            if(y==wave_y)scene=peak>4?24'hf3d497:24'h867249;
        end
        if(x>=605 && x<611 && y>=204 && y<210)
            scene=bpm!=0 && beat?24'hf3d497:24'h32281c;
        // Felt rail, fixed chassis, then individually moving key faces.
        if(x>=38 && x<602 && y>=row_top-3 && y<row_top+171)begin
            scene=24'h181411;
            if(y==row_top-2)scene=24'h622a24;
            if(y>=row_top && y<row_top+168)begin
                for(j=0;j<14;j=j+1)begin
                    left=40+j*40;note=white_note(j[3:0]);
                    drop=travel[note];face_bottom=row_top+162+drop;
                    if(x>=left && x<left+39)begin
                        key_area=1;label_drop=drop;
                        scene=24'h27221b;
                        if(y>=row_top+drop)begin
                            scene=heat[note]>40?24'he7d3aa:24'he8e2d7;
                            if(y<row_top+10+drop)scene=heat[note]>40?24'hc5a86c:24'hbdb4a5;
                            else if(y<row_top+18+drop)scene=heat[note]>40?24'hdac398:24'hd4cbbd;
                            if(y>=face_bottom)scene=keys[note]?24'h9e814d:24'hb0a797;
                            if(y==face_bottom)scene=keys[note]?24'hd7b676:24'hf4eee2;
                            if(x==left || x==left+38)scene=24'h6e6455;
                            if(x==left+1 && y<face_bottom)scene=24'hf8f0df;
                        end
                    end
                end
                for(j=0;j<10;j=j+1)begin
                    left=black_x(j[3:0]);note=black_note(j[3:0]);drop=travel[note];
                    if(x>=left && x<left+26 && y<row_top+107+drop)begin
                        scene=24'h4c4438;
                        if(x<left+24 && y<row_top+104+drop)begin
                            black_area=1;key_area=1;label_drop=drop;
                            scene=24'h090909;
                            if(y>=row_top+drop)begin
                                scene=heat[note]>40?24'h594729:24'h181716;
                                if(x<left+3 || x>=left+21)scene=heat[note]>40?24'h9d7d44:24'h3c3934;
                                if(y<row_top+4+drop)scene=heat[note]>40?24'hd5b67c:24'h59554c;
                                if(y>=row_top+97+drop)scene=heat[note]>40?24'h957443:24'h090909;
                                if(y==row_top+97+drop)scene=heat[note]>40?24'he2c289:24'h48433a;
                            end
                        end
                    end
                end
            end
        end
        // Short bars above the keybed breathe with note attacks/releases.
        if(y>=row_top-10 && y<row_top-4)for(j=0;j<14;j=j+1)begin
            note=white_note(j[3:0]);left=43+j*40;
            if(heat[note]>16 && x>=left && x<left+32 && y>=row_top-5-(heat[note]>>6))
                scene=heat[note]>160?24'hc8a665:24'h57452c;
        end
        if(y>=440 && y<474)begin
            if(x>=126 && x<202 && song_status[5])scene=24'h292319;
            if(x>=302 && x<378 && song_status[3])scene=24'h39211b;
            if(x>=390 && x<466 && bpm!=0)scene=24'h292319;
        end
    end

    reg [7:0] font_rom[0:2047];
    reg [7:0] top_rom[0:10239];
    reg [7:0] title_rom[0:8959];
    initial begin
        $readmemh("assets/font8x16.hex",font_rom);
        $readmemh("assets/ui_top_640x128.hex",top_rom);
        $readmemh("assets/ui_timbres_224x320.hex",title_rom);
    end
    wire [8:0] label_y=key_area?y-label_drop:y;
    wire [6:0] tile_x=x[9:3];
    wire [4:0] tile_y=label_y[8:4];
    wire [11:0] tile_addr=(tile_y<<6)+(tile_y<<4)+tile_x;
    wire [13:0] top_addr=y*14'd80+(x>>3);
    wire [13:0] title_addr=timbre*14'd1120+(y-9'd74)*14'd28+((x-10'd32)>>3);
    wire [15:0] volume_100=volume*16'd100+16'd128;
    wire [7:0] percent=volume>=256?8'd100:volume_100[15:8];
    reg [7:0] dynamic_char;
    reg [127:0] song_label;
    reg [2:0] glyph_bit;
    reg [3:0] glyph_row;
    reg draw_text;
    reg [23:0] ink;
    always @*begin
        case(song_status[2:0])
            0:song_label="TWINKLE         ";
            1:song_label="TWO TIGERS      ";
            2:song_label="SUNNY INTRO     ";
            3:song_label="JINGLE BELLS    ";
            4:song_label="CUSTOM SCORE    ";
            5:song_label="MY RECORDING    ";
            default:song_label="                ";
        endcase
        dynamic_char=8'h20;
        case({tile_y,tile_x})
            12'd393:dynamic_char=8'h30;
            12'd394:dynamic_char=8'h31;
            12'd900:dynamic_char=8'h54;
            12'd901:dynamic_char=8'h4F;
            12'd902:dynamic_char=8'h55;
            12'd903:dynamic_char=8'h43;
            12'd904:dynamic_char=8'h48;
            12'd906:dynamic_char=8'h2F;
            12'd908:dynamic_char=8'h4B;
            12'd909:dynamic_char=8'h45;
            12'd910:dynamic_char=8'h59;
            12'd911:dynamic_char=8'h42;
            12'd912:dynamic_char=8'h4F;
            12'd913:dynamic_char=8'h41;
            12'd914:dynamic_char=8'h52;
            12'd915:dynamic_char=8'h44;
            12'd1028:dynamic_char=8'h53;
            12'd1029:dynamic_char=8'h4F;
            12'd1030:dynamic_char=8'h4E;
            12'd1031:dynamic_char=8'h47;
            12'd1033:dynamic_char=8'h30;
            12'd1034:dynamic_char=8'h31;
            12'd1040:dynamic_char=8'h54;
            12'd1041:dynamic_char=8'h57;
            12'd1042:dynamic_char=8'h49;
            12'd1043:dynamic_char=8'h4E;
            12'd1044:dynamic_char=8'h4B;
            12'd1045:dynamic_char=8'h4C;
            12'd1046:dynamic_char=8'h45;
            12'd2441:dynamic_char=8'h43;
            12'd2442:dynamic_char=8'h23;
            12'd2446:dynamic_char=8'h44;
            12'd2447:dynamic_char=8'h23;
            12'd2456:dynamic_char=8'h46;
            12'd2457:dynamic_char=8'h23;
            12'd2461:dynamic_char=8'h47;
            12'd2462:dynamic_char=8'h23;
            12'd2466:dynamic_char=8'h41;
            12'd2467:dynamic_char=8'h23;
            12'd2476:dynamic_char=8'h43;
            12'd2477:dynamic_char=8'h23;
            12'd2481:dynamic_char=8'h44;
            12'd2482:dynamic_char=8'h23;
            12'd2491:dynamic_char=8'h46;
            12'd2492:dynamic_char=8'h23;
            12'd2496:dynamic_char=8'h47;
            12'd2497:dynamic_char=8'h23;
            12'd2501:dynamic_char=8'h41;
            12'd2502:dynamic_char=8'h23;
            12'd2569:dynamic_char=8'h53;
            12'd2574:dynamic_char=8'h44;
            12'd2584:dynamic_char=8'h47;
            12'd2589:dynamic_char=8'h48;
            12'd2594:dynamic_char=8'h4A;
            12'd2604:dynamic_char=8'h32;
            12'd2609:dynamic_char=8'h33;
            12'd2619:dynamic_char=8'h35;
            12'd2624:dynamic_char=8'h36;
            12'd2629:dynamic_char=8'h37;
            12'd3078:dynamic_char=8'h43;
            12'd3079:dynamic_char=8'h34;
            12'd3083:dynamic_char=8'h44;
            12'd3084:dynamic_char=8'h34;
            12'd3088:dynamic_char=8'h45;
            12'd3089:dynamic_char=8'h34;
            12'd3093:dynamic_char=8'h46;
            12'd3094:dynamic_char=8'h34;
            12'd3098:dynamic_char=8'h47;
            12'd3099:dynamic_char=8'h34;
            12'd3103:dynamic_char=8'h41;
            12'd3104:dynamic_char=8'h34;
            12'd3108:dynamic_char=8'h42;
            12'd3109:dynamic_char=8'h34;
            12'd3113:dynamic_char=8'h43;
            12'd3114:dynamic_char=8'h35;
            12'd3118:dynamic_char=8'h44;
            12'd3119:dynamic_char=8'h35;
            12'd3123:dynamic_char=8'h45;
            12'd3124:dynamic_char=8'h35;
            12'd3128:dynamic_char=8'h46;
            12'd3129:dynamic_char=8'h35;
            12'd3133:dynamic_char=8'h47;
            12'd3134:dynamic_char=8'h35;
            12'd3138:dynamic_char=8'h41;
            12'd3139:dynamic_char=8'h35;
            12'd3143:dynamic_char=8'h42;
            12'd3144:dynamic_char=8'h35;
            12'd3207:dynamic_char=8'h5A;
            12'd3212:dynamic_char=8'h58;
            12'd3217:dynamic_char=8'h43;
            12'd3222:dynamic_char=8'h56;
            12'd3227:dynamic_char=8'h42;
            12'd3232:dynamic_char=8'h4E;
            12'd3237:dynamic_char=8'h4D;
            12'd3242:dynamic_char=8'h51;
            12'd3247:dynamic_char=8'h57;
            12'd3252:dynamic_char=8'h45;
            12'd3257:dynamic_char=8'h52;
            12'd3262:dynamic_char=8'h54;
            12'd3267:dynamic_char=8'h59;
            12'd3272:dynamic_char=8'h55;
            12'd3589:dynamic_char=8'h50;
            12'd3590:dynamic_char=8'h52;
            12'd3591:dynamic_char=8'h45;
            12'd3592:dynamic_char=8'h56;
            12'd3602:dynamic_char=8'h50;
            12'd3603:dynamic_char=8'h4C;
            12'd3604:dynamic_char=8'h41;
            12'd3605:dynamic_char=8'h59;
            12'd3611:dynamic_char=8'h4E;
            12'd3612:dynamic_char=8'h45;
            12'd3613:dynamic_char=8'h58;
            12'd3614:dynamic_char=8'h54;
            12'd3622:dynamic_char=8'h52;
            12'd3623:dynamic_char=8'h45;
            12'd3624:dynamic_char=8'h43;
            12'd3633:dynamic_char=8'h42;
            12'd3634:dynamic_char=8'h45;
            12'd3635:dynamic_char=8'h41;
            12'd3636:dynamic_char=8'h54;
            12'd3645:dynamic_char=8'h2D;
            12'd3646:dynamic_char=8'h35;
            12'd3655:dynamic_char=8'h2B;
            12'd3656:dynamic_char=8'h35;
            default:;
        endcase
        glyph_bit=x[2:0];glyph_row=label_y[3:0];
        draw_text=1;
        ink=key_area?(black_area?24'hd0bd97:24'h41392d):24'ha9987c;
        if(tile_y==3 && tile_x==10)dynamic_char="1"+{5'b0,timbre};
        if(tile_y==8)begin
            if(tile_x==10)dynamic_char="1"+{5'b0,song_status[2:0]};
            if(tile_x>=16 && tile_x<=31)dynamic_char=song_label[((31-tile_x)*8)+:8];
            if(tile_x>=52 && tile_x<=59)begin
                if(song_status[7])begin
                    case(tile_x)
                        52:dynamic_char="S";53:dynamic_char="A";54:dynamic_char="V";55:dynamic_char="E";
                        57:dynamic_char="E";58:dynamic_char="R";59:dynamic_char="R";default:dynamic_char=" ";
                    endcase
                end else if(song_status[6])begin
                    case(tile_x)
                        52:dynamic_char="S";53:dynamic_char="A";54:dynamic_char="V";
                        55:dynamic_char="I";56:dynamic_char="N";57:dynamic_char="G";default:dynamic_char=" ";
                    endcase
                end else if(song_status[3])begin
                    case(tile_x)
                        52:dynamic_char="R";53:dynamic_char="E";54:dynamic_char="C";default:dynamic_char=" ";
                    endcase
                end
            end
        end
        if(tile_y==24)begin
            case(tile_x)
                7,12,17,22,27,32,37:dynamic_char="3"+{6'b0,octave};
                42,47,52,57,62,67,72:dynamic_char="4"+{6'b0,octave};
                default:;
            endcase
        end
        if(tile_y==28)begin
            if(tile_x==18)dynamic_char=song_status[5]?"S":"P";
            if(tile_x==19)dynamic_char=song_status[5]?"T":"L";
            if(tile_x==20)dynamic_char=song_status[5]?"O":"A";
            if(tile_x==21)dynamic_char=song_status[5]?"P":"Y";
            if(tile_x==38)dynamic_char=song_status[3]?"E":"R";
            if(tile_x==39)dynamic_char=song_status[3]?"N":"E";
            if(tile_x==40)dynamic_char=song_status[3]?"D":"C";
        end
        if(tile_y==1 && tile_x>=69 && tile_x<=76)begin
            case(tile_x)
                69:dynamic_char="U";70:dynamic_char="S";71:dynamic_char="B";
                73:dynamic_char=usb_diag>=9?"O":"0"+{4'b0,usb_diag[3:0]};
                74:dynamic_char=usb_diag>=9?"K":" ";default:dynamic_char=" ";
            endcase
        end
        // Large numeric values use the same font ROM at double size.
        if(y>=76 && y<108 && ((x>=336 && x<400)||(x>=472 && x<488)))begin
            glyph_row=(y-9'd76)>>1;glyph_bit=(x>>1)&7;
            ink=24'hece2cc;
            if(x>=472)begin dynamic_char="3"+{6'b0,octave};glyph_bit=(x-10'd472)>>1;end
            else if(x<352)dynamic_char=percent==100?"1":" ";
            else if(x<368)dynamic_char="0"+(percent/10)%10;
            else if(x<384)dynamic_char="0"+percent%10;
            else dynamic_char="%";
        end
        if(y>=80 && y<96 && x>=544 && x<568)begin
            glyph_row=y-9'd80;
            if(x<552)dynamic_char=bpm==0?"-":(bpm>=100?"0"+bpm/100:" ");
            else if(x<560)dynamic_char=bpm==0?"-":"0"+(bpm/10)%10;
            else dynamic_char=bpm==0?"-":"0"+bpm%10;
        end
    end
    reg [7:0] top_byte1=0,title_byte1=0,font_byte2=0,char1=0;
    reg [23:0] base1=0,base2=0,ink1=0,ink2=0;
    reg [2:0] glyph_bit1=0,glyph_bit2=0,mask_bit1=0,title_bit1=0;
    reg [3:0] glyph_row1=0;
    reg top_on1=0,title_on1=0,text_on1=0,text_on2=0;
    always @(posedge clk)begin
        base1<=scene;ink1<=ink;
        char1<=dynamic_char;glyph_row1<=glyph_row;glyph_bit1<=glyph_bit;
        text_on1<=draw_text;
        top_byte1<=top_rom[top_addr<10240?top_addr:0];
        title_byte1<=title_rom[title_addr<8960?title_addr:0];
        mask_bit1<=x[2:0];title_bit1<=(x-10'd32)&7;
        top_on1<=y<128;
        title_on1<=x>=32 && x<256 && y>=74 && y<114;
        base2<=base1;ink2<=ink1;
        if(top_on1 && top_byte1[7-mask_bit1])base2<=24'ha9987c;
        if(title_on1 && title_byte1[7-title_bit1])base2<=24'hf0e6d2;
        font_byte2<=font_rom[{char1[6:0],glyph_row1}];
        glyph_bit2<=glyph_bit1;text_on2<=text_on1;
        rgb<=text_on2 && font_byte2[7-glyph_bit2]?ink2:base2;
    end
endmodule
`default_nettype wire
