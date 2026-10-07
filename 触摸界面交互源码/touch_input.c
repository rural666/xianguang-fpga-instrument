#include "touch_input.h"
#include <string.h>

int touch_decode_mpi7002(const uint8_t *report, size_t length, touch_frame_t *frame){
    if(!report || !frame || length<TOUCH_REPORT_BYTES || report[0]!=1)return -1;
    /* The captured 605-byte descriptor defines SIX 10-byte Finger records,
       a 16-bit Scan Time at bytes 61..62, then Contact Count at byte 63. */
    unsigned count=report[63];
    if(count>TOUCH_MAX_CONTACTS)return -2;
    memset(frame,0,sizeof(*frame));
    /* Only entries counted by this report are valid, including Tip=0 lifts. */
    for(unsigned i=0;i<count;i++){
        size_t offset=1+10*i;
        uint16_t x=(uint16_t)(report[offset+2]|(report[offset+3]<<8));
        uint16_t y=(uint16_t)(report[offset+4]|(report[offset+5]<<8));
        if(!(report[offset]&1u) || x>800 || y>480)continue;
        frame->points[i].x=x;
        frame->points[i].y=y;
        frame->points[i].active=1;
    }
    return 0;
}

static int scene_position(const touch_point_t *point,unsigned *x,unsigned *y){
    if(!point->active || point->x>=800 || point->y>=480)return 0;
    /* HDMI is 640x480; this LCD scales it across its 800x480 panel. */
    *x=((uint32_t)point->x*640u)/800u;
    *y=point->y;
    return 1;
}

static unsigned white_note(unsigned index){
    static const uint8_t note[7]={0,2,4,5,7,9,11};
    return note[index%7]+(index>=7?12u:0u);
}
static unsigned black_note(unsigned index){
    static const uint8_t note[5]={1,3,6,8,10};
    return note[index%5]+(index>=5?12u:0u);
}
static unsigned black_left(unsigned index){
    static const uint16_t left[5]={68,108,188,228,268};
    return left[index%5]+(index>=5?280u:0u);
}

uint32_t touch_layout_notes(const touch_frame_t *frame){
    uint32_t mask=0;
    if(!frame)return 0;
    for(unsigned point=0;point<TOUCH_MAX_CONTACTS;point++){
        unsigned x,y;
        if(!scene_position(&frame->points[point],&x,&y))continue;
        if(y<256 || y>=424)continue;
        unsigned local_y=y-256;
        int found=0;
        if(local_y<104)for(unsigned k=0;k<10;k++){
            unsigned left=black_left(k);
            if(x>=left && x<left+24){mask|=1u<<black_note(k);found=1;break;}
        }
        if(!found)for(unsigned k=0;k<14;k++){
            unsigned left=40+40*k;
            if(x>=left && x<left+40){mask|=1u<<white_note(k);break;}
        }
    }
    return mask;
}

uint16_t touch_layout_buttons(const touch_frame_t *frame){
    static const uint16_t left[7]={36,126,214,302,390,488,568};
    static const uint16_t right[7]={114,202,290,378,466,560,624};
    uint16_t buttons=0;
    if(!frame)return 0;
    for(unsigned point=0;point<TOUCH_MAX_CONTACTS;point++){
        unsigned x,y;
        if(!scene_position(&frame->points[point],&x,&y))continue;
        if(y>=438 && y<476){
            for(unsigned button=0;button<7;button++){
                if(x>=left[button] && x<right[button]){
                    buttons|=(uint16_t)(1u<<button);
                    break;
                }
            }
        } else if(y>=48 && y<124){
            if(x>=24 && x<280)buttons|=TOUCH_TIMBRE_NEXT;
            else if(x>=296 && x<360)buttons|=TOUCH_VOLUME_DOWN;
            else if(x>=360 && x<432)buttons|=TOUCH_VOLUME_UP;
            else if(x>=440 && x<480)buttons|=TOUCH_OCTAVE_DOWN;
            else if(x>=480 && x<532)buttons|=TOUCH_OCTAVE_UP;
        }
    }
    return buttons;
}
