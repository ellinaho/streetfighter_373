// emg.c
#include "emg.h"

void emg_init(EmgDetector *ed)
{
    ed->state           = EMG_STATE_IDLE;
    ed->clench_start_ms = 0;
    ed->clench_ticks    = 0;
    ed->miss_ticks      = 0;
    ed->charge          = 0;
    ed->multiplier      = 0.0f;
    ed->window_ticks    = 0;
}

// call this when a punch fires — clears accumulated charge
void emg_on_punch(EmgDetector *ed)
{
    ed->charge      = 0;
    ed->multiplier  = 0.0f;
    ed->state       = EMG_STATE_IDLE;
    ed->miss_ticks  = 0;
    ed->clench_ticks = 0;
    ed->window_ticks = 0;
}

EmgResult emg_update(EmgDetector *ed, uint16_t sample, uint32_t now_ms)
{
    EmgResult result = {0};

    // Active when signal spikes HIGH (flexing) — tune EMG_THRESHOLD between rest and flex values
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
                // too short — treat as noise
                // if we already had charge built up, go back to CHARGED so
                // multiplier isn't lost; otherwise return to IDLE
                ed->state        = (ed->multiplier > 0.0f) ? EMG_STATE_CHARGED : EMG_STATE_IDLE;
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

            // linear multiplier: 2.0 at EMG_MIN_CHARGE, 4.0 at EMG_MAX_CHARGE
            // below EMG_MIN_CHARGE = not enough charge yet, stays 0
            if (ed->charge >= EMG_MIN_CHARGE) {
                float t        = (float)(ed->charge - EMG_MIN_CHARGE)
                               / (float)(EMG_MAX_CHARGE - EMG_MIN_CHARGE);
                float new_mult = EMG_MULT_MIN + t * (EMG_MULT_MAX - EMG_MULT_MIN);
                // round to 1 decimal place
                new_mult = (float)(int)(new_mult * 10.0f + 0.5f) / 10.0f;
                if (new_mult > ed->multiplier)
                    ed->multiplier = new_mult;
            }
        }
        // either way, move to CHARGED if we have any multiplier, else idle
        if (ed->multiplier > 0.0f) {
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
        if (above && ed->multiplier < EMG_MULT_MAX) {
            ed->state           = EMG_STATE_CLENCHING;
            ed->clench_start_ms = now_ms;
            ed->clench_ticks    = 1;
            ed->miss_ticks      = 0;
            ed->window_ticks    = 1;
        }
        break;
    }

    result.charge = ed->charge;
    return result;
}
