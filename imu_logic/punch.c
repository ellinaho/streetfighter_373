//punch.c
#include "punch.h"

//takes the raw imu reading and converts it to g-force units
//by dividing by the scale factor from the imu datasheet
static float to_g(int16_t raw) {
    return (float)raw / IMU_SCALE;
}

//takes the difference in each axis and returns the overall magnitude
static float magnitude(float dx, float dy, float dz) {
    return sqrtf(dx*dx + dy*dy + dz*dz);
}

//sets up the punch detector to its starting state
//x0 y0 z0 are the resting accelerometer values so we know
//what "not moving" looks like
void punch_init(PunchDetector *pd, float x0, float y0, float z0) {
    pd->state                = PUNCH_STATE_IDLE;
    pd->window_start_ms      = 0;
    pd->cooldown_start_ms    = 0;
    pd->peak_mag             = 0.0f;
    pd->samples_in_window    = 0;
    pd->samples_above_thresh = 0;
    pd->baseline_x           = x0;
    pd->baseline_y           = y0;
    pd->baseline_z           = z0;
}

//this is the main function that gets called every time we get
//a new imu reading. it runs the state machine to figure out
//if a punch happened and how hard it was
PunchResult punch_update(PunchDetector *pd, int16_t raw_x, int16_t raw_y, int16_t raw_z, uint32_t now_ms)
{
    //zero out the result so nothing is valid by default
    PunchResult result = {0};

    //convert raw readings to gs then subtract the baseline
    //so we only care about the change in acceleration not gravity
    float dx = to_g(raw_x) - pd->baseline_x;
    float dy = to_g(raw_y) - pd->baseline_y;
    float dz = to_g(raw_z) - pd->baseline_z;
    //get the total magnitude of that change
    float mag = magnitude(dx, dy, dz);

    switch (pd->state) {

    //idle state just sits here waiting until the acceleration
    //goes above the threshold meaning a punch might be starting
    case PUNCH_STATE_IDLE:
        if (mag > PUNCH_THRESH_G) {
            //something crossed the threshold so switch to active
            //and start tracking this potential punch
            pd->state                = PUNCH_STATE_ACTIVE;
            pd->window_start_ms      = now_ms;
            pd->peak_mag             = mag;
            pd->samples_in_window    = 1;
            pd->samples_above_thresh = 1;
        }
        break;

    //active state means we think a punch is happening
    //we keep collecting samples to see how strong and consistent it is
    case PUNCH_STATE_ACTIVE:
        pd->samples_in_window++;
        //keep track of the highest acceleration we saw
        if (mag > pd->peak_mag)          pd->peak_mag = mag;
        //count how many samples stayed above the threshold
        if (mag > PUNCH_THRESH_G)        pd->samples_above_thresh++;

        //how long since the punch started
        uint32_t elapsed = now_ms - pd->window_start_ms;
        //if we hit the max window time the punch is over
        int window_expired = (elapsed >= PUNCH_WINDOW_MS);
        //if acceleration dropped well below threshold and some
        //time passed the punch ended naturally on its own
        int naturally_ended = (mag < PUNCH_THRESH_G * 0.6f && elapsed > 80);

        if (window_expired || naturally_ended) {
            //punch is done now we decide if it was real
            //consistency is what fraction of samples were above threshold
            float consistency = (float)pd->samples_above_thresh
                              / (float)pd->samples_in_window;
            //check if the peak was high enough to count
            int peak_valid    = (pd->peak_mag >= PUNCH_PEAK_G);

#if USE_CONSISTENCY
            //if consistency checking is on we need both a strong peak
            //and enough samples above threshold to count it
            int confirmed = peak_valid && (consistency >= CONSISTENCY_MIN);
#else
            //if consistency checking is off just check the peak
            int confirmed = peak_valid;
#endif

            if (confirmed) {
                //punch is confirmed so fill in the result
                result.valid       = 1;
                result.peak_mag    = pd->peak_mag;
                result.consistency = consistency;
                //damage scales with how far above the threshold
                //the peak was. harder punch = more damage
                result.damage = BASE_DMG
                              + SCALE_FACTOR * (pd->peak_mag - PUNCH_THRESH_G);
            }

            //always go to cooldown even if punch wasnt confirmed
            //this stops the follow through motion from triggering
            //another punch detection
            pd->state             = PUNCH_STATE_COOLDOWN;
            pd->cooldown_start_ms = now_ms;
        }
        break;

    //cooldown state is a lockout period where we ignore everything
    //once enough time passes we go back to idle and listen again
    case PUNCH_STATE_COOLDOWN:
        if ((now_ms - pd->cooldown_start_ms) >= PUNCH_COOLDOWN_MS) {
            pd->state = PUNCH_STATE_IDLE;
        }
        break;
    }

    return result;
}