/*
 * test_emg_main.c
 * Standalone EMG powerup charge test for STM32L432KC.
 *
 * The EMG signal comes in on ADC1 (same channel as actual main).
 * TIM6 fires every 1ms to trigger ADC reads at 1kHz.
 * Results are printed over LPUART1 (115200 baud).
 *
 * State machine:
 *   IDLE       -> waiting for clench above threshold
 *   CLENCHING  -> accumulating ticks, tolerates short dropouts
 *   EVALUATING -> checks peak ratio, adds to charge if quality clench
 *   CHARGED    -> powerup ready, signals main STM until punch resets it
 *
 * For combined main: copy the USER CODE sections below into your main.c.
 * emg.h and emg.c must be in your project's Inc/Src folders.
 */

#include "main.h"
#include "emg.h"
#include "stdio.h"

/* ── Handles declared by CubeIDE ─────────────────────────────── */
extern ADC_HandleTypeDef  hadc1;
extern TIM_HandleTypeDef  htim6;
extern UART_HandleTypeDef hlpuart1;

/* ── Globals ─────────────────────────────────────────────────── */
static EmgDetector       ed;
static volatile uint8_t  emg_read_flag = 0;   // set by TIM6 ISR every 1ms

/* ── Retarget printf to LPUART1 ─────────────────────────────── */
#ifdef __GNUC__
#define PUTCHAR_PROTOTYPE int __io_putchar(int ch)
#else
#define PUTCHAR_PROTOTYPE int fputc(int ch, FILE *f)
#endif
PUTCHAR_PROTOTYPE
{
    HAL_UART_Transmit(&hlpuart1, (uint8_t *)&ch, 1, 0xFFFF);
    return ch;
}

/* ── TIM6 ISR: 1ms tick for EMG sampling ─────────────────────── */
// NOTE: if sharing TIM6 with punch (10ms), either use a separate timer
// or let the punch code set its own flag on every 10th tick here
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM6) {
        emg_read_flag = 1;
    }
}

/* ── Read one ADC sample (blocking single conversion) ────────── */
static uint16_t read_emg_adc(void)
{
    HAL_ADC_Start(&hadc1);
    HAL_ADC_PollForConversion(&hadc1, HAL_MAX_DELAY);
    return (uint16_t)HAL_ADC_GetValue(&hadc1);
}

/* ── Main ────────────────────────────────────────────────────── */
int main(void)
{
    HAL_Init();
    SystemClock_Config();
    MX_GPIO_Init();
    MX_ADC1_Init();
    MX_LPUART1_UART_Init();
    MX_TIM6_Init();

    HAL_ADCEx_Calibration_Start(&hadc1, ADC_SINGLE_ENDED);

    emg_init(&ed);

    HAL_TIM_Base_Start_IT(&htim6);

    printf("\r\n=== EMG Powerup Test ===\r\n");
    printf("Threshold: %d  MinClench: %dms  MissLimit: %d ticks\r\n",
           EMG_THRESHOLD, EMG_MIN_CLENCH_MS, EMG_MISS_LIMIT);
    printf("Clench and hold to charge. Max multiplier: %dx\r\n\r\n",
           EMG_MAX_MULTIPLIER);

    while (1) {
        if (emg_read_flag) {
            emg_read_flag = 0;

            uint16_t  sample = read_emg_adc();
            uint32_t  now    = HAL_GetTick();
            EmgResult res    = emg_update(&ed, sample, now);

            if (res.charged) {
                // powerup ready — in combined main this sends value to main STM
                printf("CHARGED! multiplier=%dx  charge=%lu\r\n",
                       res.multiplier, (unsigned long)ed.charge);
            }

            // example: simulate punch resetting charge (tie to punch detection)
            // emg_on_punch(&ed);
        }
    }
}
