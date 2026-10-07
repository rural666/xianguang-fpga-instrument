#ifndef XIANGUANG_TOUCH_INPUT_H
#define XIANGUANG_TOUCH_INPUT_H

#include <stddef.h>
#include <stdint.h>

#define TOUCH_MAX_CONTACTS 6u
#define TOUCH_REPORT_BYTES 64u
#define TOUCH_PREV   (1u << 0)
#define TOUCH_PLAY   (1u << 1)
#define TOUCH_NEXT   (1u << 2)
#define TOUCH_RECORD (1u << 3)
#define TOUCH_BEAT   (1u << 4)
#define TOUCH_SLOWER (1u << 5)
#define TOUCH_FASTER (1u << 6)
#define TOUCH_TIMBRE_NEXT (1u << 7)
#define TOUCH_VOLUME_DOWN (1u << 8)
#define TOUCH_VOLUME_UP (1u << 9)
#define TOUCH_OCTAVE_DOWN (1u << 10)
#define TOUCH_OCTAVE_UP (1u << 11)

typedef struct {
    uint16_t x, y; /* Raw MPI7002 coordinates: 0..800, 0..480. */
    uint8_t active;
} touch_point_t;

typedef struct {
    touch_point_t points[TOUCH_MAX_CONTACTS];
} touch_frame_t;

/* Return 0 for report ID 1, negative for unrelated or malformed reports. */
int touch_decode_mpi7002(const uint8_t *report, size_t length, touch_frame_t *frame);
uint32_t touch_layout_notes(const touch_frame_t *frame);
uint16_t touch_layout_buttons(const touch_frame_t *frame);

#endif
