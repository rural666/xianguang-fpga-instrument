#ifndef INSTRUMENT_KEYS_H
#define INSTRUMENT_KEYS_H
#include <stdint.h>
#include <stddef.h>
#include "touch_input.h"
typedef void (*instrument_send_fn)(void *, const char *);
typedef struct {
    uint32_t keys;
    uint16_t ticks; /* flags=0: 16 ticks/beat; flags=1: milliseconds. */
    uint16_t flags;
} score_event_t;
#define RECORD_CAPACITY 4096u
typedef struct {
    uint8_t held[256];
    uint32_t mask, touch_mask, song_mask, sent_mask;
    uint8_t volume, octave, timbre, tilt, locked, room, vibrato, pedal_latch, pedal;
    uint8_t connected, keyboard_connected, touch_connected;
    uint16_t touch_buttons;
    uint8_t inhibited, demo, metronome_on, bpm, song_active, score_bpm;
    uint16_t song_index, score_count;
    uint32_t last_report, touch_last_report, last_tick, song_next, song_gate, f1_released_at;
    const score_event_t *score;
    const score_event_t *slots[6];
    uint16_t slot_counts[6];
    uint8_t slot_bpms[6];
    score_event_t *record_events;
    uint16_t record_count, record_capacity;
    uint32_t record_start, record_last;
    uint32_t record_mask;
    uint8_t selected_song, recording, record_pending, record_saving;
    uint8_t record_save_error, status_sent;
    instrument_send_fn send;
    void *context;
} instrument_keys_t;
void instrument_init(instrument_keys_t *, instrument_send_fn, void *);
int instrument_set_score(instrument_keys_t *, const score_event_t *, size_t, unsigned);
int instrument_set_recording(instrument_keys_t *, score_event_t *, size_t, size_t);
int instrument_select_song(instrument_keys_t *, unsigned);
void instrument_record_saved(instrument_keys_t *, int);
void instrument_connect(instrument_keys_t *, uint32_t);
void instrument_disconnect(instrument_keys_t *);
void instrument_touch_connect(instrument_keys_t *, uint32_t);
void instrument_touch_disconnect(instrument_keys_t *);
int instrument_report(instrument_keys_t *, const uint8_t *, size_t, uint32_t);
void instrument_touch_report(instrument_keys_t *, const touch_frame_t *, uint32_t);
void instrument_tick(instrument_keys_t *, uint32_t);
#endif
