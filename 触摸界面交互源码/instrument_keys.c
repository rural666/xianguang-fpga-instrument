#include "instrument_keys.h"
#include "song_library.h"
#include <string.h>

// C4..B4: Z S X D C V G B H N J M; C5..B5: Q 2 W 3 E R 5 T 6 Y 7 U.
static const uint8_t notes[24]={
    0x1d,0x16,0x1b,0x07,0x06,0x19,0x0a,0x05,0x0b,0x11,0x0d,0x10,
    0x14,0x1f,0x1a,0x20,0x08,0x15,0x22,0x17,0x23,0x1c,0x24,0x18
};
static const char hex[]="0123456789ABCDEF";
static void tx(instrument_keys_t *s,const char *v){s->send(s->context,v);}
static void packet(instrument_keys_t *s,char kind,unsigned v){
    char out[7]={kind,hex[(v>>8)&15],hex[(v>>4)&15],hex[v&15],0,';',0};
    out[4]=hex[((v>>8)^((v>>4)&15)^(v&15)^(kind=='!'?5:10))&15];tx(s,out);
}
static void send_notes(instrument_keys_t *s){
    uint32_t keys=s->mask|s->touch_mask|s->song_mask;
    if((keys&0xfff)!=(s->sent_mask&0xfff))packet(s,'Q',keys&0xfff);
    if((keys>>12)!=(s->sent_mask>>12))packet(s,'H',keys>>12);
    s->sent_mask=keys;
}
static unsigned status_value(const instrument_keys_t *s){
    return s->selected_song | (s->recording?8u:0u) |
        (s->slot_counts[SONG_RECORDING]?16u:0u) | (s->song_active?32u:0u) |
        (s->record_saving?64u:0u) | (s->record_save_error?128u:0u);
}
static void send_status(instrument_keys_t *s){
    unsigned value=status_value(s);
    if(s->connected && s->status_sent!=value+1u){packet(s,'S',value);s->status_sent=value+1u;}
}
static void stop_song(instrument_keys_t *s){
    s->song_active=0;s->song_mask=0;send_notes(s);send_status(s);
}
static void record_append(instrument_keys_t *s,uint32_t mask,uint32_t elapsed){
    while(elapsed && s->record_count<s->record_capacity){
        uint16_t take=elapsed>65535u?65535u:(uint16_t)elapsed;
        s->record_events[s->record_count++]=(score_event_t){mask,take,1};
        elapsed-=take;
    }
}
static uint16_t trim_recording_tail(score_event_t *events,uint16_t count){
    uint16_t first=count;
    uint32_t silence=0;
    while(first && events[first-1].keys==0){
        --first;
        silence+=events[first].ticks;
    }
    if(silence<=1000u)return count;
    /* A missed REC release can leave minutes of silence after the last note.
       Keep a short natural ending without making replay appear stuck. */
    events[first]=(score_event_t){0,1000,1};
    return first+1;
}
static void finish_record(instrument_keys_t *s,uint32_t now){
    if(!s->recording)return;
    record_append(s,s->record_mask,now-s->record_last);
    s->recording=0;
    s->record_count=trim_recording_tail(s->record_events,s->record_count);
    if(s->record_count){
        s->slots[SONG_RECORDING]=s->record_events;
        s->slot_counts[SONG_RECORDING]=s->record_count;
        s->slot_bpms[SONG_RECORDING]=s->bpm;
        s->selected_song=SONG_RECORDING;
        s->score=s->record_events;s->score_count=s->record_count;s->score_bpm=s->bpm;
        s->record_pending=1;s->record_save_error=0;
    }
    send_status(s);
}
static void record_transition(instrument_keys_t *s,uint32_t mask,uint32_t now){
    if(!s->recording || s->record_mask==mask)return;
    record_append(s,s->record_mask,now-s->record_last);
    s->record_last=now;s->record_mask=mask;
    if(s->record_count>=s->record_capacity)finish_record(s,now);
}
static void panic(instrument_keys_t *s){
    tx(s,"X");s->mask=s->touch_mask=s->song_mask=s->sent_mask=0;
    s->song_active=0;s->pedal=s->pedal_latch=s->demo=0;
}
static void start_song_event(instrument_keys_t *s,uint32_t start){
    if(s->song_index>=s->score_count){stop_song(s);return;}
    const score_event_t *e=&s->score[s->song_index];
    uint32_t duration=e->flags==1?e->ticks:
        ((uint32_t)e->ticks*60000u)/((uint32_t)s->bpm*16u);
    if(duration==0)duration=1;
    uint32_t gap=e->flags==1?0:duration/8u;
    if(gap>80u)gap=80u;
    s->song_next=start+duration;
    s->song_gate=s->song_next-gap;
    s->song_mask=e->keys;
    send_notes(s);
}
static void toggle_song(instrument_keys_t *s,uint32_t now){
    if(s->recording)return;
    if(s->song_active){stop_song(s);return;}
    panic(s);
    if(s->metronome_on){packet(s,'T',0);packet(s,'T',s->bpm);}
    s->song_active=1;s->song_index=0;start_song_event(s,now);send_status(s);
}
static void select_adjacent(instrument_keys_t *s,int direction,uint32_t now){
    if(s->recording)return;
    unsigned slot=s->selected_song;
    for(unsigned n=0;n<SONG_SLOT_COUNT;n++){
        slot=(slot+(direction>0?1u:SONG_SLOT_COUNT-1u))%SONG_SLOT_COUNT;
        if(s->slot_counts[slot]){
            int was_playing=s->song_active;
            if(was_playing)stop_song(s);
            instrument_select_song(s,slot);
            if(was_playing){
                s->song_active=1;s->song_index=0;
                start_song_event(s,now);send_status(s);
            }
            return;
        }
    }
}
static void toggle_record(instrument_keys_t *s,uint32_t now){
    if(s->recording)finish_record(s,now);
    else if(!s->record_pending && !s->record_saving && s->record_events &&
            s->record_capacity && !s->song_active){
        s->record_count=0;s->record_mask=s->mask|s->touch_mask;
        s->record_last=s->record_start=now;
        s->recording=1;s->record_save_error=0;send_status(s);
    }
}
static void toggle_metronome(instrument_keys_t *s){
    s->metronome_on=!s->metronome_on;
    packet(s,'T',s->metronome_on?s->bpm:0);
}
static void change_bpm(instrument_keys_t *s,int direction){
    if(direction<0 && s->bpm>40)s->bpm-=5;
    if(direction>0 && s->bpm<240)s->bpm+=5;
    if(s->metronome_on)packet(s,'T',s->bpm);
}
static void change_volume(instrument_keys_t *s,int direction){
    int next=(int)s->volume+direction;
    if(next<0)next=0;
    if(next>100)next=100;
    if(next==s->volume)return;
    s->volume=(uint8_t)next;
    packet(s,'!',(s->volume*256+50)/100);
}
static void change_octave(instrument_keys_t *s,int direction){
    if(direction<0 && s->octave>0){panic(s);tx(s,"<");s->octave--;}
    else if(direction>0 && s->octave<2){panic(s);tx(s,">");s->octave++;}
}
static void cycle_timbre(instrument_keys_t *s){
    char command[2]={(char)('1'+((s->timbre+1u)&7u)),0};
    s->timbre=(uint8_t)((s->timbre+1u)&7u);
    tx(s,command);
}
void instrument_init(instrument_keys_t *s,instrument_send_fn send,void *context){
    memset(s,0,sizeof(*s));s->send=send;s->context=context;
    s->volume=100;s->octave=1;s->locked=s->room=1;s->bpm=120;
    for(unsigned i=0;i<SONG_CUSTOM;i++){
        const song_entry_t *entry=song_library_builtin(i);
        s->slots[i]=entry->events;s->slot_counts[i]=entry->count;s->slot_bpms[i]=entry->bpm;
    }
    instrument_select_song(s,SONG_TWINKLE);
}
int instrument_select_song(instrument_keys_t *s,unsigned slot){
    if(slot>=SONG_SLOT_COUNT || !s->slot_counts[slot] || s->song_active || s->recording)return -1;
    s->selected_song=(uint8_t)slot;s->score=s->slots[slot];
    s->score_count=s->slot_counts[slot];s->score_bpm=s->slot_bpms[slot];
    s->bpm=s->score_bpm;
    if(s->connected && s->metronome_on)packet(s,'T',s->bpm);
    send_status(s);return 0;
}
int instrument_set_score(instrument_keys_t *s,const score_event_t *events,size_t count,unsigned bpm){
    if(!events || count==0 || count>4096 || bpm<40 || bpm>240 || s->song_active)return -1;
    for(size_t i=0;i<count;i++)
        if((events[i].keys&~0xffffffu) || !events[i].ticks ||
           events[i].ticks>4096 || events[i].flags)return -1;
    s->slots[SONG_CUSTOM]=events;s->slot_counts[SONG_CUSTOM]=(uint16_t)count;
    s->slot_bpms[SONG_CUSTOM]=(uint8_t)bpm;
    return instrument_select_song(s,SONG_CUSTOM);
}
int instrument_set_recording(instrument_keys_t *s,score_event_t *events,size_t capacity,size_t count){
    if(!events || !capacity || capacity>RECORD_CAPACITY || count>capacity || s->recording || s->record_saving)return -1;
    for(size_t i=0;i<count;i++)
        if((events[i].keys&~0xffffffu)||!events[i].ticks||events[i].flags!=1)return -1;
    count=trim_recording_tail(events,(uint16_t)count);
    s->record_events=events;s->record_capacity=(uint16_t)capacity;
    s->record_count=(uint16_t)count;
    s->slots[SONG_RECORDING]=events;s->slot_counts[SONG_RECORDING]=(uint16_t)count;
    s->slot_bpms[SONG_RECORDING]=120;
    send_status(s);return 0;
}
void instrument_record_saved(instrument_keys_t *s,int success){
    s->record_saving=0;s->record_save_error=!success;send_status(s);
}
static void bring_online(instrument_keys_t *s,uint32_t now){
    s->connected=1;s->inhibited=1;
    s->last_report=s->last_tick=now;panic(s);
    s->volume=100;s->tilt=0;s->locked=1;s->room=1;s->vibrato=0;
    s->metronome_on=0;s->bpm=s->score_bpm;
    tx(s,"bX1nRrV<<>");s->octave=1;s->timbre=0;
    packet(s,'T',0);
    s->status_sent=0;send_status(s);
}
void instrument_connect(instrument_keys_t *s,uint32_t now){
    memset(s->held,0,sizeof(s->held));s->keyboard_connected=1;s->inhibited=1;
    s->last_report=now;
    if(!s->connected)bring_online(s,now);
}
void instrument_touch_connect(instrument_keys_t *s,uint32_t now){
    s->touch_connected=1;s->touch_mask=0;s->touch_buttons=0;
    s->touch_last_report=now;
    if(!s->connected)bring_online(s,now);
}
void instrument_disconnect(instrument_keys_t *s){
    s->keyboard_connected=0;
    if(s->touch_connected){
        record_transition(s,s->touch_mask,s->last_report);
        s->mask=0;s->inhibited=1;memset(s->held,0,sizeof(s->held));
        send_notes(s);return;
    }
    if(s->recording)finish_record(s,s->last_report);
    if(s->connected)tx(s,"Xz");
    s->connected=0;s->inhibited=1;s->mask=s->touch_mask=s->song_mask=s->sent_mask=0;
    s->song_active=0;s->pedal=s->pedal_latch=s->demo=0;s->status_sent=0;
    memset(s->held,0,sizeof(s->held));
}
void instrument_touch_disconnect(instrument_keys_t *s){
    record_transition(s,s->mask,s->touch_last_report);
    s->touch_connected=0;s->touch_mask=0;s->touch_buttons=0;
    if(s->keyboard_connected){send_notes(s);return;}
    s->last_report=s->touch_last_report;
    instrument_disconnect(s);
}
int instrument_report(instrument_keys_t *s,const uint8_t *r,size_t n,uint32_t now){
    uint8_t next[256]={0};unsigned i;uint32_t mask=0;int any=0;
    if(!s->keyboard_connected)return -1;
    // Fn/media-key transitions on some 2.4G receivers briefly leave the
    // eight-byte boot-keyboard format. They must not cancel a running score.
    if(n!=8){if(!s->song_active && !s->recording){panic(s);s->inhibited=1;}return -2;}
    for(i=2;i<8;i++){
        if(r[i]>=1&&r[i]<=3){if(!s->song_active && !s->recording){panic(s);s->inhibited=1;}return -3;}
        if(r[i]){next[r[i]]=1;any=1;}
    }
    s->last_report=now;
    if(r[0]&0xdd){
        if(!s->song_active && !s->recording){panic(s);s->inhibited=1;memcpy(s->held,next,256);}
        return 0;
    }
    if(s->inhibited){
        if(!any){s->inhibited=0;memset(s->held,0,256);}
        return 0;
    }
    if(next[0x29]&&!s->held[0x29]){
        finish_record(s,now);panic(s);s->inhibited=1;memcpy(s->held,next,256);
        send_status(s);return 0;
    }
    for(i=0;i<256;i++)if(next[i]&&!s->held[i]){
        switch(i){
        case 0x3a:
            // Ignore a brief duplicate F1 report caused by key release bounce.
            if(s->song_active){
                if((uint32_t)(now-s->f1_released_at)>=200u)toggle_song(s,now);
            }
            else toggle_song(s,now);
            break;
        case 0x3b:panic(s);tx(s,"1P");s->demo=1;s->inhibited=1;memcpy(s->held,next,256);return 0;
        case 0x3c:s->tilt=!s->tilt;s->locked=!s->tilt;tx(s,s->tilt?"mc":"n");break;
        case 0x3d:s->locked=1;tx(s,"L");break;
        case 0x3e:s->volume=100;s->locked=1;tx(s,"R");break;
        case 0x3f:s->tilt=1;s->locked=0;tx(s,"mc");break;
        case 0x40:s->room=!s->room;tx(s,s->room?"r":"x");break;
        case 0x41:s->vibrato=!s->vibrato;tx(s,s->vibrato?"v":"V");break;
        case 0x42:if(!s->song_active)s->pedal_latch=!s->pedal_latch;break;
        case 0x43:toggle_metronome(s);break;
        case 0x44:change_bpm(s,-1);break;
        case 0x45:change_bpm(s,1);break;
        case 0x4f: /* Right arrow: next available song. */
        case 0x50:select_adjacent(s,i==0x4f?1:-1,now);break;
        case 0x49: /* Insert: start/stop live recording. */
            toggle_record(s,now);break;
        case 0x4e:change_octave(s,-1);break;
        case 0x4b:change_octave(s,1);break;
        case 0x2e:change_volume(s,10);break;
        case 0x2d:change_volume(s,-10);break;
        default:break;
        }
    }
    // During automatic playback only F1 or Esc stops the score. Ignoring
    // piano usages here also prevents an Fn release's ghost key from cutting
    // the song short; ordinary manual playing resumes as soon as it stops.
    if(!s->song_active)for(i=0;i<24;i++)if(next[notes[i]])mask|=(uint32_t)(1u<<i);
    {int pedal=!s->song_active && (next[0x2c]||s->pedal_latch);
     if(pedal!=s->pedal){tx(s,pedal?"o":"O");s->pedal=(uint8_t)pedal;}}
    if(mask!=s->mask){
        record_transition(s,mask|s->touch_mask,now);
        s->mask=mask;send_notes(s);s->demo=0;
    }
    if(!next[0x3a] && s->held[0x3a])s->f1_released_at=now;
    memcpy(s->held,next,256);return 0;
}
void instrument_touch_report(instrument_keys_t *s,const touch_frame_t *frame,uint32_t now){
    if(!s->touch_connected || !frame)return;
    s->touch_last_report=now;
    uint16_t buttons=touch_layout_buttons(frame);
    uint16_t new_buttons=(uint16_t)(buttons & ~s->touch_buttons);
    s->touch_buttons=buttons;
    if(new_buttons&TOUCH_PREV)select_adjacent(s,-1,now);
    if(new_buttons&TOUCH_PLAY)toggle_song(s,now);
    if(new_buttons&TOUCH_NEXT)select_adjacent(s,1,now);
    if(new_buttons&TOUCH_RECORD)toggle_record(s,now);
    if(new_buttons&TOUCH_BEAT)toggle_metronome(s);
    if(new_buttons&TOUCH_SLOWER)change_bpm(s,-1);
    if(new_buttons&TOUCH_FASTER)change_bpm(s,1);
    if(new_buttons&TOUCH_TIMBRE_NEXT)cycle_timbre(s);
    if(new_buttons&TOUCH_VOLUME_DOWN)change_volume(s,-10);
    if(new_buttons&TOUCH_VOLUME_UP)change_volume(s,10);
    if(new_buttons&TOUCH_OCTAVE_DOWN)change_octave(s,-1);
    if(new_buttons&TOUCH_OCTAVE_UP)change_octave(s,1);
    uint32_t mask=s->song_active?0:touch_layout_notes(frame);
    if(mask!=s->touch_mask){
        record_transition(s,s->mask|mask,now);
        s->touch_mask=mask;send_notes(s);s->demo=0;
    }
}
void instrument_tick(instrument_keys_t *s,uint32_t now){
    if(!s->connected)return;
    // The song keeps playing even if a receiver sends no idle key reports.
    // A real USB disconnect still calls instrument_disconnect immediately.
    if(s->song_active)s->last_report=now;
    if(s->keyboard_connected && (uint32_t)(now-s->last_report)>1500 && !s->inhibited){
        finish_record(s,now);panic(s);s->inhibited=1;send_status(s);
    }
    if(s->recording && (uint32_t)(now-s->record_start)>=300000u)
        finish_record(s,now);
    if(s->song_active){
        if(s->song_mask && (int32_t)(now-s->song_gate)>=0){s->song_mask=0;send_notes(s);}
        while(s->song_active && (int32_t)(now-s->song_next)>=0){
            uint32_t start=s->song_next;
            s->song_index++;
            start_song_event(s,start);
        }
    }
    if((uint32_t)(now-s->last_tick)>=100){tx(s,"bk");s->last_tick=now;}
    send_status(s);
}
