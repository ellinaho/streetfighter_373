// emg.c
#include "emg.h"

void emg_init(EmgDetector *ed)
{
    ed->state           = EMG_STATE_IDLE;
    ed->clench_start_ms = 0;
    ed->clench_ticks    = 0;
    ed->miss_ticks      = 0;
    ed->charge          = 0;
    ed->multiplier      = 0;
    ed->window_ticks    = 0;
}

// call this when a punch fires — clears accumulated charge
void emg_on_punch(EmgDetector *ed)
{
    ed->charge      = 0;
    ed->multiplier  = 0;
    ed->state       = EMG_STATE_IDLE;
    ed->miss_ticks  = 0;
    ed->clench_ticks = 0;
    ed->window_ticks = 0;
}

EmgResult emg_update(EmgDetector *ed, uint16_t sample, uint32_t now_ms)
{
    EmgResult result = {0};

    uint8_t above = (sample >= EMG_THRESHOLD);

    switch (ed->state) {

    // ── IDLE ──────────────────────────────────────────────────
    // just waiting for a signal that could be the start of a clench
    case EMG_STATE_IDLE:
    default:
        if (above) {
            ed->state           = EMG_STATE_CLENCHING;
            ed->clench_start_ms = now_ms;
            ed->clench_ticks    = 1;
            ed->miss_ticks      = 0;
            ed->window_ticks    = 1;
        }
        break;

    // ── CLENCHING ─────────────────────────────────────────────
    // collecting samples while the user is actively clenching
    // we allow short dropouts (miss_ticks) before giving up
    case EMG_STATE_CLENCHING:
        ed->window_ticks++;

        if (above) {
            ed->clench_ticks++;
            ed->miss_ticks = 0;     // reset dropout counter on any good sample
        } else {
            ed->miss_ticks++;
        }

        // too many consecutive misses — clench has ended, go evaluate
        if (ed->miss_ticks >= EMG_MISS_LIMIT) {
            uint32_t elapsed = now_ms - ed->clench_start_ms;
            if (elapsed >= EMG_MIN_CLENCH_MS) {
                // held long enough to be worth evaluating
                ed->state = EMG_STATE_EVALUATING;
            } else {
                // too short — treat as noise, go back to idle
                ed->state        = EMG_STATE_IDLE;
                ed->clench_ticks = 0;
                ed->miss_ticks   = 0;
                ed->window_ticks = 0;
            }
        }
        break;

    // ── EVALUATING ────────────────────────────────────────────
    // clench just ended — check if the quality was good enough
    // (enough samples above threshold) then add to charge
    case EMG_STATE_EVALUATING: {
        float ratio = (ed->window_ticks > 0)
                      ? ((float)ed->clench_ticks / (float)ed->window_ticks)
                      : 0.0f;

        if (ratio >= EMG_PEAK_RATIO) {
            // quality clench — add the above-threshold ticks to charge
            ed->charge += ed->clench_ticks;

            // clamp to max
            if (ed->charge > EMG_MAX_CHARGE)
                ed->charge = EMG_MAX_CHARGE;

            // compute multiplier from charge bucket
            // charge/denom gives 0–3, cap at EMG_MAX_MULTIPLIER
            uint8_t new_mult = (uint8_t)(ed->charge / EMG_CHARGE_DENOM);
            if (new_mult > EMG_MAX_MULTIPLIER)
                new_mult = EMG_MAX_MULTIPLIER;

            if (new_mult > ed->multiplier) {
                ed->multiplier = new_mult;
            }
        }
        // either way, move to CHARGED if we have any multiplier, else idle
        if (ed->multiplier > 0) {
            ed->state = EMG_STATE_CHARGED;
        } else {
            ed->state = EMG_STATE_IDLE;
        }

        // reset per-clench scratch
        ed->clench_ticks = 0;
        ed->miss_ticks   = 0;
        ed->window_ticks = 0;
        break;
    }

    // ── CHARGED ───────────────────────────────────────────────
    // powerup is ready — signal the main STM every update tick
    // until a punch fires (emg_on_punch resets us to idle)
    case EMG_STATE_CHARGED:
        result.charged    = 1;
        result.multiplier = ed->multiplier;

        // if user starts clenching again, go back to clenching
        // so they can keep building charge up to the cap
        if (above && ed->multiplier < EMG_MAX_MULTIPLIER) {
            ed->state           = EMG_STATE_CLENCHING;
            ed->clench_start_ms = now_ms;
            ed->clench_ticks    = 1;
            ed->miss_ticks      = 0;
            ed->window_ticks    = 1;
        }
        break;
    }

    return result;
}
