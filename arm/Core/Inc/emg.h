// emg.h
#ifndef EMG_H
#define EMG_H

#include <stdint.h>

// ── Tunable constants ─────────────────────────────────────────

// ADC threshold = active (flexing) when signal goes ABOVE this value.
#define EMG_THRESHOLD        750      // raw ADC counts — tune to your sensor

// Fraction of samples in the clench window that must exceed threshold
// to confirm a real clench (not noise)
#define EMG_PEAK_RATIO       0.15f     // 15% of samples must be above threshold

// Minimum clench duration to count toward charge
#define EMG_MIN_CLENCH_MS    200      // must clench for at least 200ms

// How many consecutive below-threshold ticks before we decide clench ended
#define EMG_MISS_LIMIT       25       // at 1ms sampling = 25ms dropout tolerance

// Sampling interval (matches your ADC/timer setup)
#define EMG_SAMPLE_MS        10       // 1ms = 1kHz sampling

// Charge accumulator — ~70% of ticks are above threshold on a noisy EMG,
// so 1s real clench ≈ 700 above-threshold ticks. 3s = 2100 = max charge.
#define EMG_MAX_CHARGE       2100     // ticks needed for full charge (~2s of above-threshold signal)
#define EMG_MIN_CHARGE       300      // ticks needed for minimum multiplier (~0.3s of signal)

// Multiplier range: 1s clench = 2.0x, 3s clench = 4.0x, linear between
#define EMG_MULT_MIN         2.0f     // multiplier at EMG_MIN_CHARGE
#define EMG_MULT_MAX         4.0f     // multiplier at EMG_MAX_CHARGE

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
    float     multiplier;           // current powerup multiplier (0.0 = none, 2.0–4.0 when charged)

    // evaluation scratch
    uint32_t  window_ticks;         // total ticks in the clench window (above + miss)
} EmgDetector;

typedef struct {
    uint8_t  charged;               // 1 = powerup ready to send
    float    multiplier;            // powerup level (2.0–4.0), 0.0 if not charged
    uint32_t charge;                // raw charge ticks — for debug printing only
} EmgResult;

void       emg_init(EmgDetector *ed);
EmgResult  emg_update(EmgDetector *ed, uint16_t sample, uint32_t now_ms);

// Call this when a punch fires — resets the charge accumulator
void       emg_on_punch(EmgDetector *ed);

#endif
