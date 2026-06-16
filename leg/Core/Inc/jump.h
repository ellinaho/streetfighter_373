/*
 * jump.h
 *
 *  Created on: Apr 12, 2026
 *      Author: joshuachen
 */

#ifndef SRC_JUMP_H_
#define SRC_JUMP_H_

#include <stdint.h>
#include <math.h>

// ── Tunable constants ─────────────────────────────────────────
// DO NOT CHANGE: must match TIM6 period (10ms = 100Hz IMU sample rate)
#define JUMP_SAMPLE_INTERVAL_MS  10

// TUNE: raise if walking or weight shifts trigger false jumps,
//       lower if real jumps are being missed. check printf DBG output.
#define JUMP_THRESH_G            1.5f     // g-force to open jump window

// TUNE: raise if crouching/stomping falsely confirms a jump,
//       lower if jumps are opening a window but never confirming.
//       must be > JUMP_THRESH_G.
#define JUMP_PEAK_G              2.5f     // peak g-force required to confirm jump

// TUNE: raise if the push-off spike is being captured too slowly,
//       lower if leg shuffling is keeping the window open too long.
#define JUMP_WINDOW_MS           500      // max time (ms) from thresh crossing to close

// TUNE: raise if landing impact re-triggers a jump detect,
//       lower if player needs to jump again quickly.
#define JUMP_COOLDOWN_MS         800      // lockout period (ms) after jump fires

#define IMU_SCALE                15000.0f

typedef enum {
    JUMP_STATE_IDLE,
    JUMP_STATE_ACTIVE,
    JUMP_STATE_COOLDOWN
} JumpState;

typedef struct {
    JumpState state;
    uint32_t  window_start_ms;
    uint32_t  cooldown_start_ms;
    float     peak_mag;
    uint32_t  samples_in_window;
    uint32_t  samples_above_thresh;
    float     baseline_x;
    float     baseline_y;
    float     baseline_z;
} JumpDetector;

typedef struct {
    uint8_t valid;      // 1 = jump confirmed
    float   peak_mag;
    float   mag;        // current magnitude (debug)
} JumpResult;

void jump_init(JumpDetector *jd, float x0, float y0, float z0);
JumpResult jump_update(JumpDetector *jd,
                       int16_t raw_x, int16_t raw_y, int16_t raw_z,
                       uint32_t now_ms);

#endif
