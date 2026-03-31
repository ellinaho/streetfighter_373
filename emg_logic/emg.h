// emg.h
#ifndef EMG_H
#define EMG_H

#include <stdint.h>

// ── Tunable constants ─────────────────────────────────────────

// ADC threshold — active (flexing) when signal goes ABOVE this value.
// Set between your resting value and your peak flex value.
#define EMG_THRESHOLD        500      // raw ADC counts — tune to your sensor

// Fraction of samples in the clench window that must exceed threshold
// to confirm a real clench (not noise)
#define EMG_PEAK_RATIO       0.6f     // 60% of samples must be above threshold

// Minimum clench duration to count toward charge
#define EMG_MIN_CLENCH_MS    1000     // must clench for at least 1 second

// How many consecutive below-threshold ticks before we decide clench ended
#define EMG_MISS_LIMIT       20       // at 1ms sampling = 20ms dropout tolerance

// Sampling interval (matches your ADC/timer setup)
#define EMG_SAMPLE_MS        1        // 1ms = 1kHz sampling

// Charge accumulator — max is 3000 ticks at 1ms = 3 seconds clamped
#define EMG_MAX_CHARGE       3000     // raw tick count
#define EMG_CHARGE_DENOM     1000     // divide by this to get 0–3 range

// Powerup multiplier cap (e.g. 3x max)
#define EMG_MAX_MULTIPLIER   3

// ── State machine ─────────────────────────────────────────────

typedef enum {
    EMG_STATE_IDLE,
    EMG_STATE_CLENCHING,
    EMG_STATE_EVALUATING,
    EMG_STATE_CHARGED
} EmgState;

typedef struct {
    EmgState  state;

    // clench window tracking
    uint32_t  clench_start_ms;      // when current clench began
    uint32_t  clench_ticks;         // total ticks spent above threshold this clench
    uint32_t  miss_ticks;           // consecutive ticks below threshold

    // charge accumulator
    uint32_t  charge;               // accumulated charge (capped at EMG_MAX_CHARGE)
    uint8_t   multiplier;           // current powerup multiplier (0–EMG_MAX_MULTIPLIER)

    // evaluation scratch
    uint32_t  window_ticks;         // total ticks in the clench window (above + miss)
} EmgDetector;

typedef struct {
    uint8_t  charged;               // 1 = powerup ready to send
    uint8_t  multiplier;            // powerup level (1–EMG_MAX_MULTIPLIER)
} EmgResult;

void       emg_init(EmgDetector *ed);
EmgResult  emg_update(EmgDetector *ed, uint16_t sample, uint32_t now_ms);

// Call this when a punch fires — resets the charge accumulator
void       emg_on_punch(EmgDetector *ed);

#endif
