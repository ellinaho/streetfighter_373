// jump.c
// DEBUG prints (prefixed "DBG:") are for tuning only — comment out before final build.
#include "jump.h"
#include <stdio.h>

static float to_g(int16_t raw) {
    return (float)raw / IMU_SCALE;
}

static float magnitude(float dx, float dy, float dz) {
    return sqrtf(dx*dx + dy*dy + dz*dz);
}

void jump_init(JumpDetector *jd, float x0, float y0, float z0) {
    jd->state                = JUMP_STATE_IDLE;
    jd->window_start_ms      = 0;
    jd->cooldown_start_ms    = 0;
    jd->peak_mag             = 0.0f;
    jd->samples_in_window    = 0;
    jd->samples_above_thresh = 0;
    jd->baseline_x           = x0;
    jd->baseline_y           = y0;
    jd->baseline_z           = z0;
}

JumpResult jump_update(JumpDetector *jd,
                       int16_t raw_x, int16_t raw_y, int16_t raw_z,
                       uint32_t now_ms)
{
    JumpResult result = {0};

    float dx  = to_g(raw_x) - jd->baseline_x;
    float dy  = to_g(raw_y) - jd->baseline_y;
    float dz  = to_g(raw_z) - jd->baseline_z;
    float mag = magnitude(dx, dy, dz);

    result.mag = mag;

    switch (jd->state) {

    case JUMP_STATE_IDLE:
        if (mag > JUMP_THRESH_G) {
            //printf("DBG: jump window OPEN mag=%.2fg\r\n", mag);
            jd->state                = JUMP_STATE_ACTIVE;
            jd->window_start_ms      = now_ms;
            jd->peak_mag             = mag;
            jd->samples_in_window    = 1;
            jd->samples_above_thresh = 1;
        }
        break;

    case JUMP_STATE_ACTIVE:
        jd->samples_in_window++;
        if (mag > jd->peak_mag)     jd->peak_mag = mag;
        if (mag > JUMP_THRESH_G)    jd->samples_above_thresh++;

        uint32_t elapsed       = now_ms - jd->window_start_ms;
        int      window_expired  = (elapsed >= JUMP_WINDOW_MS);
        // naturally ends when leg settles back to near-rest after push-off
        int      naturally_ended = (mag < JUMP_THRESH_G * 0.75f);

        if (window_expired || naturally_ended) {
            int peak_valid = (jd->peak_mag >= JUMP_PEAK_G);
            //printf("DBG: jump window CLOSE peak=%.2fg valid=%d why=%s\r\n",
                   //jd->peak_mag, peak_valid,
                   //window_expired ? "expired" : "natural");

            if (peak_valid) {
                result.valid    = 1;
                result.peak_mag = jd->peak_mag;
            }

            jd->state             = JUMP_STATE_COOLDOWN;
            jd->cooldown_start_ms = now_ms;
        }
        break;

    case JUMP_STATE_COOLDOWN:
        if ((now_ms - jd->cooldown_start_ms) >= JUMP_COOLDOWN_MS) {
            jd->state = JUMP_STATE_IDLE;
        }
        break;
    }

    return result;
}
