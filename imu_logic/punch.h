// punch.h
#ifndef PUNCH_H
#define PUNCH_H

#include <stdint.h>
#include <math.h>

// ── Tunable constants ─────────────────────────────────────────
#define SAMPLE_INTERVAL_MS   10       // 100 Hz
#define PUNCH_THRESH_G       1.2f     // start of punch window
#define PUNCH_PEAK_G         1.5f     // must exceed this to be valid
#define PUNCH_WINDOW_MS      400      // max duration of a punch gesture
#define PUNCH_COOLDOWN_MS    500      // lockout after punch fires
#define IMU_SCALE            15000.0f // LSM303 scale (matches actual IMU main)

// Consistency mode: fraction of samples above threshold to count as real punch
#define USE_CONSISTENCY      1
#define CONSISTENCY_MIN      0.4f     // at least 40% of window above thresh

// Damage formula: dmg = BASE_DMG + SCALE_FACTOR * (peak - thresh)
#define BASE_DMG             10.0f
#define SCALE_FACTOR         20.0f

typedef enum {
    PUNCH_STATE_IDLE,
    PUNCH_STATE_ACTIVE,
    PUNCH_STATE_COOLDOWN
} PunchState;

typedef struct {
    PunchState  state;
    uint32_t    window_start_ms;
    uint32_t    cooldown_start_ms;
    float       peak_mag;
    uint32_t    samples_in_window;
    uint32_t    samples_above_thresh;
    float       baseline_x;           // x0, y0, z0 at rest
    float       baseline_y;
    float       baseline_z;
} PunchDetector;

typedef struct {
    uint8_t  valid;       // 1 = punch confirmed
    float    damage;
    float    peak_mag;
    float    consistency;
} PunchResult;

void          punch_init(PunchDetector *pd, float x0, float y0, float z0);
PunchResult   punch_update(PunchDetector *pd,
                           int16_t raw_x, int16_t raw_y, int16_t raw_z,
                           uint32_t now_ms);
#endif