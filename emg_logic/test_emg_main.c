/*
 * test_emg_main.c
 * Standalone EMG powerup charge test for STM32L432KC.
 *
 * Timing architecture:
 *   TIM6 hardware-triggers ADC every 1ms (no ISR needed to start ADC).
 *   ADC completion fires HAL_ADC_ConvCpltCallback which calls emg_update.
 *   Main loop only handles printing — zero timing sensitivity.
 *
 * CubeIDE config required:
 *   ADC1 -> External Trigger: TIM6 Trigger Out Event, Rising Edge
 *   TIM6 -> Trigger Output (TRGO): Update Event
 *   ADC1 interrupt enabled (NVIC)
 *   TIM6 period = (SystemCoreClock / 1000) - 1  for 1ms
 */

#include "main.h"
#include "emg.h"
#include "stdio.h"

/* ── Handles declared by CubeIDE ─────────────────────────────── */
extern ADC_HandleTypeDef  hadc1;
extern TIM_HandleTypeDef  htim6;
extern UART_HandleTypeDef hlpuart1;

/* ── Globals ──────────────────────────────────────────────────── */
static EmgDetector        ed;
static volatile EmgResult emg_result;          // written in ADC ISR, read in main
static volatile uint8_t   emg_result_ready = 0;

/* ── Retarget printf to LPUART1 ──────────────────────────────── */
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

/* ── ADC conversion complete ISR ─────────────────────────────── */
// Fires automatically when TIM6 triggers ADC and conversion finishes.
// Does all EMG work here — guaranteed 1ms cadence, no polling.
void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef *hadc)
{
    if (hadc->Instance == ADC1) {
        uint16_t  sample = (uint16_t)HAL_ADC_GetValue(hadc);
        uint32_t  now    = HAL_GetTick();
        EmgResult res    = emg_update(&ed, sample, now);
        emg_result       = res;
        emg_result_ready = 1;
    }
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

    // Start ADC in interrupt mode — TIM6 hardware trigger fires conversions
    HAL_ADC_Start_IT(&hadc1);
    // TIM6 runs freely, its TRGO triggers ADC every 1ms
    HAL_TIM_Base_Start(&htim6);

    printf("\r\n=== EMG Powerup Test ===\r\n");
    printf("Threshold: %d  MinClench: %dms  MissLimit: %d ticks\r\n",
           EMG_THRESHOLD, EMG_MIN_CLENCH_MS, EMG_MISS_LIMIT);
    printf("Clench and hold to charge. Max multiplier: %dx\r\n\r\n",
           EMG_MAX_MULTIPLIER);

    float last_multiplier = 0.0f;

    while (1) {
        // main loop only prints — all timing-sensitive work is in the ADC ISR
        if (emg_result_ready) {
            emg_result_ready = 0;
            EmgResult res = emg_result;  // local copy so ISR can't clobber mid-print

            if (res.charged && res.multiplier != last_multiplier) {
                last_multiplier = res.multiplier;
                printf("CHARGED! multiplier=%.1fx  charge=%lu\r\n",
                       res.multiplier, (unsigned long)ed.charge);
            }
            if (!res.charged && last_multiplier != 0.0f) {
                last_multiplier = 0.0f;
                printf("charge reset\r\n");
            }
        }
    }
}
