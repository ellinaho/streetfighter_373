/*
 * test_punch_main.c
 * Standalone punch detection test for STM32L432KC + LSM303 over I2C.
 *
 * Hardware wiring (Nucleo-L432KC):
 *   LSM303 VCC  -> 3.3V
 *   LSM303 GND  -> GND
 *   LSM303 SDA  -> I2C1_SDA
 *   LSM303 SCL  -> I2C1_SCL
 *   LPUART1 TX  -> built-in ST-Link Virtual COM Port (115200 baud)
 *
 * Timer TIM6 fires an interrupt every 10ms (100 Hz) to trigger IMU reads.
 * Punch results are printed over LPUART1 visible via any serial terminal.
 *
 * Paste the USER CODE sections into your combined main.c as noted below.
 * punch.h and punch.c must be in your project's Inc/Src folders.
 */

#include "main.h"
#include "punch.h"
#include "stdio.h"

/* ── LSM303 defines (matches actual IMU main) ─────────────────── */
#define SAD_W_M     0x32          // I2C write address
#define SAD_R_M     0x33          // I2C read address
#define OUT_X_L_A   0b10101000    // accel output register, auto-increment

/* ── Handles declared by CubeIDE ─────────────────────────────── */
extern I2C_HandleTypeDef  hi2c1;
extern TIM_HandleTypeDef  htim6;
extern UART_HandleTypeDef hlpuart1;

/* ── Globals ─────────────────────────────────────────────────── */
static PunchDetector     pd;
static volatile uint8_t  imu_read_flag = 0;  // set by TIM6 ISR every 10ms

/* ── Retarget printf to LPUART1 (same as actual main) ────────── */
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

/* ── LSM303 init (mirrors actual IMU main setup) ─────────────── */
static void lsm303_init(void)
{
    uint8_t buf[2];
    // reg 0x20 = CTRL_REG1_A: ODR=400Hz, all axes enabled (0b10010111)
    buf[0] = 0x20;
    buf[1] = 0b10010111;
    HAL_I2C_Master_Transmit(&hi2c1, SAD_W_M, buf, 2, 1000);
}

/* ── Read all 3 accel axes in one burst ─────────────────────── */
static void lsm303_read_accel(int16_t *ax, int16_t *ay, int16_t *az)
{
    uint8_t reg = OUT_X_L_A;
    uint8_t buf[6];
    HAL_I2C_Master_Transmit(&hi2c1, SAD_W_M, &reg, 1, 1000);
    HAL_I2C_Master_Receive(&hi2c1,  SAD_R_M, buf,  6, 1000);
    // LSM303 is little-endian: low byte first
    *ax = (int16_t)((buf[1] << 8) | buf[0]);
    *ay = (int16_t)((buf[3] << 8) | buf[2]);
    *az = (int16_t)((buf[5] << 8) | buf[4]);
}

/* ── TIM6 ISR: set flag every 10ms for 100Hz sampling ────────── */
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM6) {
        imu_read_flag = 1;
    }
}

/* ── Calibration: average N samples at rest ─────────────────── */
static void calibrate_baseline(float *bx, float *by, float *bz)
{
    #define CAL_SAMPLES 64
    int32_t sx = 0, sy = 0, sz = 0;
    int16_t ax, ay, az;

    printf("Calibrating... hold still\r\n");
    for (int i = 0; i < CAL_SAMPLES; i++) {
        lsm303_read_accel(&ax, &ay, &az);
        sx += ax; sy += ay; sz += az;
        HAL_Delay(10);
    }
    *bx = ((float)sx / CAL_SAMPLES) / IMU_SCALE;
    *by = ((float)sy / CAL_SAMPLES) / IMU_SCALE;
    *bz = ((float)sz / CAL_SAMPLES) / IMU_SCALE;
    printf("Baseline: %.3f  %.3f  %.3f g\r\n", *bx, *by, *bz);
}

/* ── Main ────────────────────────────────────────────────────── */
int main(void)
{
    HAL_Init();
    SystemClock_Config();
    MX_GPIO_Init();
    MX_I2C1_Init();
    MX_LPUART1_UART_Init();
    MX_TIM6_Init();

    printf("\r\n=== Punch Detection Test ===\r\n");

    lsm303_init();

    float bx, by, bz;
    calibrate_baseline(&bx, &by, &bz);
    punch_init(&pd, bx, by, bz);

    HAL_TIM_Base_Start_IT(&htim6);

    printf("Ready. Punch the sensor!\r\n");

    while (1) {
        if (imu_read_flag) {
            imu_read_flag = 0;

            int16_t ax, ay, az;
            lsm303_read_accel(&ax, &ay, &az);

            uint32_t now = HAL_GetTick();
            PunchResult res = punch_update(&pd, ax, ay, az, now);

            if (res.valid) {
                printf("PUNCH! dmg=%.1f peak=%.2fg consist=%.0f%%\r\n",
                       res.damage, res.peak_mag, res.consistency * 100.0f);
            }
        }
    }
}
