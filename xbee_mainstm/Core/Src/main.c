/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "fatfs.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "stdio.h"
#include "string.h"
#include "sfx.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define DEVICE_ADDR  0b100
#define P1_ARM_ADDR  0b000
#define P1_LEG_ADDR  0b001
#define P2_ARM_ADDR  0b010
#define P2_LEG_ADDR  0b011
#define START_BYTE   0xFF
#define TIMEOUT_MS   50

/* ── BGM filenames — change these to swap tracks ──────────────── */
#define BGM_INTRO    "introken.wav"
#define BGM_GAME     "bgm.wav"
#define BGM_GAMEOVER "gameover.wav"

#define AUDIO_BUF_SAMPLES 3200          /* 100ms per half at 16 kHz */
#define HALF_BUF_SAMPLES  (AUDIO_BUF_SAMPLES / 2)
uint8_t  raw[HALF_BUF_SAMPLES * 2];   /* scratch buffer for SD reads */
uint16_t audio_out[AUDIO_BUF_SAMPLES]; /* DMA output (circular double-buffer) */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
DAC_HandleTypeDef hdac1;
DMA_HandleTypeDef hdma_dac1_ch1;

UART_HandleTypeDef hlpuart1;
UART_HandleTypeDef huart2;
DMA_HandleTypeDef hdma_lpuart1_rx;

SPI_HandleTypeDef hspi1;
SPI_HandleTypeDef hspi2;

TIM_HandleTypeDef htim2;

/* USER CODE BEGIN PV */

/* ── UART inter-STM communication ─────────────────────────────── */
uint8_t rx_buf[3]   = {0};
uint8_t rx_copy[3]  = {0};
uint8_t local_copy[3] = {0};
uint8_t tx_buf[3]   = {0};

uint8_t current_slave        = P1_ARM_ADDR;
uint8_t waiting_for_response = 0;
volatile uint8_t uart_tx_busy      = 0;
volatile uint8_t process_rx_buf    = 0;
uint32_t request_time        = 0;

/* ── Player state decoded from UART (arm/leg nodes) ───────────── */
uint8_t p1_punch        = 0;
uint8_t p1_jump         = 0;
uint8_t p1_joystick_val = 0;
uint8_t p1_emg_val      = 0;
uint8_t p2_punch        = 0;
uint8_t p2_jump         = 0;
uint8_t p2_joystick_val = 0;
uint8_t p2_emg_val      = 0;

/* ── Game state decoded from FPGA SPI rxData ──────────────────── */
uint8_t p1_got_hit      = 0;
uint8_t p2_got_hit      = 0;
uint8_t p1_win          = 0;
uint8_t p2_win          = 0;
uint8_t p1_jump_snd     = 0;
uint8_t p2_jump_snd     = 0;
uint8_t p1_punch_snd    = 0;
uint8_t p2_punch_snd    = 0;
uint8_t p1_charging_snd = 0;
uint8_t p2_charging_snd = 0;

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_DMA_Init(void);
static void MX_LPUART1_UART_Init(void);
static void MX_SPI1_Init(void);
static void MX_DAC1_Init(void);
static void MX_TIM2_Init(void);
static void MX_SPI2_Init(void);
static void MX_USART2_UART_Init(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* Decode a 3-byte packet received from an arm/leg node via UART */
void process(uint8_t *buf) {
    uint8_t second_byte = buf[1];
    if ((second_byte & 0b111) == P1_ARM_ADDR) {
        p1_punch        = (buf[1] >> 6) & 0x01;
        p1_joystick_val = buf[2] & 0x3;
        p1_emg_val      = buf[2] >> 2;
        if (p1_punch & p1_joystick_val) p1_joystick_val = 0;
    } else if ((second_byte & 0b111) == P2_ARM_ADDR) {
        p2_punch        = (buf[1] >> 6) & 0x01;
        p2_joystick_val = buf[2] & 0x3;
        p2_emg_val      = buf[2] >> 2;
        if (p2_punch & p2_joystick_val) p2_joystick_val = 0;
    } else if ((second_byte & 0b111) == P1_LEG_ADDR) {
        p1_jump = buf[1] >> 7;
    } else if ((second_byte & 0b111) == P2_LEG_ADDR) {
        p2_jump = buf[1] >> 7;
    }
}

/* SPI transaction helper — pulls CS low, transfers, releases CS */
void SPI_TransmitReceive(uint8_t *txData, uint8_t *rxData, uint16_t size) {
    HAL_GPIO_WritePin(GPIOF, GPIO_PIN_12, GPIO_PIN_RESET);
    HAL_SPI_TransmitReceive(&hspi1, txData, rxData, size, 100);
    HAL_GPIO_WritePin(GPIOF, GPIO_PIN_12, GPIO_PIN_SET);
}

/* UART RX complete: copy buffer, advance slave, re-arm receiver */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
    if (huart->Instance == USART2) {
        memcpy(local_copy, rx_buf, 3);
        process_rx_buf = 1;
        switch (current_slave) {
            case P1_ARM_ADDR: current_slave = P1_LEG_ADDR; break;
            case P1_LEG_ADDR: current_slave = P2_ARM_ADDR; break;
            case P2_ARM_ADDR: current_slave = P2_LEG_ADDR; break;
            case P2_LEG_ADDR: current_slave = P1_ARM_ADDR; break;
        }
        waiting_for_response = 0;
        HAL_UART_Receive_IT(&huart2, rx_buf, 3);
    }
}

/* UART TX complete: release busy flag */
void HAL_UART_TxCpltCallback(UART_HandleTypeDef *huart) {
    if (huart->Instance == USART2) {
        uart_tx_busy = 0;
    }
}

/* UART error: re-arm receiver so polling doesn't permanently stop */
void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart) {
    if (huart->Instance == USART2) {
        uart_tx_busy = 0;
        huart2.RxState = HAL_UART_STATE_READY;
        huart2.gState  = HAL_UART_STATE_READY;
        HAL_UART_Receive_IT(&huart2, rx_buf, 3);
    }
}

FATFS SDFatFs;
char SDPath[4] = "0:/";
FIL wavFile;
FRESULT fres;
uint32_t data_start_offset = 0;  /* byte offset of first audio sample in WAV */

volatile int half_ready = 0;
volatile int full_ready = 0;
volatile int playing    = 0;

const int16_t    *sfx_data = NULL;  /* SFX stored as const array in flash */
volatile uint32_t sfx_len  = 0;
volatile uint32_t sfx_pos  = 0;
static int16_t    sfx_gain = 1;     /* multiplier applied to SFX samples */

/* ── Game event flags ─────────────────────────────────────────────
 * Set these from your packet-receive / UART callback when events arrive.
 * Main loop consumes and clears them.                                  */
volatile uint8_t p1_punch_flag      = 0;
volatile uint8_t p2_punch_flag      = 0;
volatile uint8_t p1_jump_flag       = 0;
volatile uint8_t p2_jump_flag       = 0;
volatile uint8_t game_started       = 0;  /* 0 = intro screen, 1 = game running */
volatile uint8_t game_countdown_flag = 0; /* set during pre-game countdown — plays ready[] */
volatile uint8_t game_over_flag      = 0; /* set when match ends — chains perfect → you_win */
volatile uint8_t timesup_flag        = 0; /* set when round timer expires */

/* ── BGM switch state ──────────────────────────────────────────── */
static uint8_t      bgm_state          = 0;     /* 0=intro BGM, 1=game BGM, 2=game over, 3=time's up */
static uint8_t      bgm_switch_pending = 0;
static const char  *pending_bgm_file   = NULL;
static uint8_t      bgm_muted          = 0;     /* 1 = silence BGM, SFX still plays */
static FIL          pendingWavFile;
static uint32_t     pending_data_start = 0;
static uint8_t      bgm_preloaded      = 0;     /* 1 = pendingWavFile already open and seeked */

/* ── SFX queue — up to 3 chained SFX play sequentially ────────── */
#define SFX_QUEUE_MAX 3
typedef struct { const int16_t *data; uint32_t len; } SfxEntry;
static SfxEntry sfx_queue[SFX_QUEUE_MAX];
static uint8_t  sfx_q_head = 0;
static uint8_t  sfx_q_tail = 0;

void HAL_DAC_ConvHalfCpltCallbackCh1(DAC_HandleTypeDef *hdac)
{
    half_ready = 1;
}

void HAL_DAC_ConvCpltCallbackCh1(DAC_HandleTypeDef *hdac)
{
    full_ready = 1;
}

static int wav_seek_to_data(void)
{
    UINT br;
    uint8_t hdr[12];
    uint8_t chunk[8];


    // Read RIFF header
    if (f_lseek(&wavFile, 0) != FR_OK) return 0;
    if (f_read(&wavFile, hdr, 12, &br) != FR_OK || br != 12) return 0;


    // Check "RIFF" and "WAVE"
    if (hdr[0] != 'R' || hdr[1] != 'I' || hdr[2] != 'F' || hdr[3] != 'F') return 0;
    if (hdr[8] != 'W' || hdr[9] != 'A' || hdr[10] != 'V' || hdr[11] != 'E') return 0;


    while (1) {
        if (f_read(&wavFile, chunk, 8, &br) != FR_OK || br != 8) return 0;


        uint32_t chunk_size =
            ((uint32_t)chunk[4]) |
            ((uint32_t)chunk[5] << 8) |
            ((uint32_t)chunk[6] << 16) |
            ((uint32_t)chunk[7] << 24);


        // Found "data"
        if (chunk[0] == 'd' && chunk[1] == 'a' && chunk[2] == 't' && chunk[3] == 'a') {
            return 1;
        }


        // Skip this chunk
        if (f_lseek(&wavFile, f_tell(&wavFile) + chunk_size) != FR_OK) return 0;


        // Chunks are word-aligned
        if (chunk_size & 1) {
            if (f_lseek(&wavFile, f_tell(&wavFile) + 1) != FR_OK) return 0;
        }
    }
}




/* Stream n samples from SD into dst, loop BGM at EOF, mix SFX from flash */
static void fill_output(uint16_t *dst, uint32_t n)
{
    uint32_t bytes_needed = n * 2;
    UINT br = 0;

    /* One read, FatFS handles cluster boundaries internally */
    f_read(&wavFile, raw, bytes_needed, &br);

    /* Only seek back if we actually hit EOF mid-buffer */
    if (f_eof(&wavFile) && br < bytes_needed) {
        f_lseek(&wavFile, data_start_offset);
        UINT br2 = 0;
        f_read(&wavFile, &raw[br], bytes_needed - br, &br2);
        br += br2;
    }

    uint32_t got_samples = br / 2;
    for (uint32_t i = 0; i < n; i++) {
        int32_t bgm = (i < got_samples && !bgm_muted)
            ? (int32_t)(int16_t)((raw[2*i+1] << 8) | raw[2*i])
            : 0;

        /* Advance to next queued SFX the moment the current one finishes */
        if (sfx_data && sfx_pos >= sfx_len) {
            if (sfx_q_head != sfx_q_tail) {
                sfx_data   = sfx_queue[sfx_q_head].data;
                sfx_len    = sfx_queue[sfx_q_head].len;
                sfx_pos    = 0;
                sfx_q_head = (sfx_q_head + 1) % SFX_QUEUE_MAX;
            } else {
                sfx_data = NULL;
            }
        }

        int32_t sfx = 0;
        if (sfx_data && sfx_pos < sfx_len)
            sfx = (int32_t)sfx_data[sfx_pos++] * sfx_gain;

        int32_t out = bgm + sfx;
        if (out >  32767) out =  32767;
        if (out < -32768) out = -32768;
        dst[i] = (uint16_t)((out + 32768) >> 4);
    }
}

void Play_SFX_Gain(const int16_t *data, uint32_t len, int16_t gain)
{
    sfx_q_head = sfx_q_tail = 0;   /* clear pending chain */
    sfx_data = data;
    sfx_len  = len;
    sfx_pos  = 0;
    sfx_gain = gain;
}

/* Play a one-shot SFX immediately, clearing any pending chain */
void Play_SFX(const int16_t *data, uint32_t len)
{
    Play_SFX_Gain(data, len, 1);
}

/* Queue a follow-up SFX to play after the current one finishes */
void Queue_SFX(const int16_t *data, uint32_t len)
{
    uint8_t next = (sfx_q_tail + 1) % SFX_QUEUE_MAX;
    if (next != sfx_q_head) {   /* silently drop if queue full */
        sfx_queue[sfx_q_tail].data = data;
        sfx_queue[sfx_q_tail].len  = len;
        sfx_q_tail = next;
    }
}


/* Open a WAV file and seek to its PCM data — SD must already be mounted */
static int open_bgm_file(const char *filename)
{
    fres = f_open(&wavFile, filename, FA_READ);
    printf("f_open(%s) = %d\r\n", filename, fres);
    if (fres != FR_OK) return 0;

    if (!wav_seek_to_data()) {
        printf("WAV data chunk not found\r\n");
        f_close(&wavFile);
        return 0;
    }

    data_start_offset = f_tell(&wavFile);
    return 1;
}

/* Mount SD then open file — call only on first open at startup */
static int open_bgm(const char *filename)
{
    fres = f_mount(&SDFatFs, (TCHAR const*)SDPath, 1);
    printf("f_mount = %d\r\n", fres);
    if (fres != FR_OK) return 0;
    return open_bgm_file(filename);
}

/* Switch BGM without remounting — pre-open while SFX plays, swap instantly when done */
static void do_bgm_switch(void)
{
    if (!bgm_switch_pending) return;

    /* Pre-open the pending file while SFX is still playing */
    if (!bgm_preloaded) {
        FRESULT r = f_open(&pendingWavFile, pending_bgm_file, FA_READ);
        if (r == FR_OK) {
            FIL tmp = wavFile;
            wavFile = pendingWavFile;
            if (wav_seek_to_data()) {
                pending_data_start = f_tell(&wavFile);
                bgm_preloaded = 1;
            }
            wavFile = tmp;   /* restore current file */
        }
        return;  /* don't swap yet, wait for SFX to finish */
    }

    /* SFX still playing — keep waiting */
    if (sfx_data != NULL) return;

    /* SFX done — swap instantly, file is already open and seeked */
    f_close(&wavFile);
    wavFile          = pendingWavFile;
    data_start_offset = pending_data_start;
    bgm_switch_pending = 0;
    bgm_preloaded      = 0;
}

static void start_wav_playback(void)
{
    printf("Starting playback...\r\n");

    if (!open_bgm_file(BGM_INTRO)){
        printf("Open failed\r\n");
        HAL_Delay(500);
        return;
    }

    /* Pre-fill both halves before handing off to DMA */
    fill_output(&audio_out[0],                HALF_BUF_SAMPLES);
    fill_output(&audio_out[HALF_BUF_SAMPLES], HALF_BUF_SAMPLES);

    HAL_TIM_Base_Start(&htim2);
    HAL_DAC_Start_DMA(&hdac1, DAC_CHANNEL_1,
                      (uint32_t*)audio_out, AUDIO_BUF_SAMPLES,
                      DAC_ALIGN_12B_R);

    playing = 1;
    printf("Playback started!\r\n");
}




/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_DMA_Init();
  MX_LPUART1_UART_Init();
  MX_SPI1_Init();
  MX_DAC1_Init();
  MX_TIM2_Init();
  MX_FATFS_Init();
  MX_SPI2_Init();
  MX_USART2_UART_Init();
  /* USER CODE BEGIN 2 */

  HAL_UART_Receive_IT(&huart2, rx_buf, 3);

  /* Mount SD card once at startup — never remount in the main loop */
  fres = f_mount(&SDFatFs, (TCHAR const*)SDPath, 1);
  printf("f_mount = %d\r\n", fres);

  printf("Start code\r\n");

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
      /* --- UART round-robin: poll arm/leg nodes ------------------- */
      if (!waiting_for_response) {
          process(local_copy);

          if (current_slave == P1_ARM_ADDR) {
              tx_buf[0] = START_BYTE;
              tx_buf[1] = (DEVICE_ADDR | (P1_ARM_ADDR << 3));
              tx_buf[2] = p1_got_hit;
          } else if (current_slave == P1_LEG_ADDR) {
              tx_buf[0] = START_BYTE;
              tx_buf[1] = (DEVICE_ADDR | (P1_LEG_ADDR << 3));
              tx_buf[2] = 0;
          } else if (current_slave == P2_ARM_ADDR) {
              tx_buf[0] = START_BYTE;
              tx_buf[1] = (DEVICE_ADDR | (P2_ARM_ADDR << 3));
              tx_buf[2] = p2_got_hit;
          } else {
              tx_buf[0] = START_BYTE;
              tx_buf[1] = (DEVICE_ADDR | (P2_LEG_ADDR << 3));
              tx_buf[2] = 0;
          }

          if (!uart_tx_busy) {
              uart_tx_busy = 1;
              HAL_UART_Transmit_IT(&huart2, tx_buf, 3);
              waiting_for_response = 1;
              request_time = HAL_GetTick();
          }
      } else {
          if (HAL_GetTick() - request_time > TIMEOUT_MS) {
              printf("Timeout on slave %d\r\n", current_slave);
              switch (current_slave) {
                  case P1_ARM_ADDR: current_slave = P1_LEG_ADDR; break;
                  case P1_LEG_ADDR: current_slave = P2_ARM_ADDR; break;
                  case P2_ARM_ADDR: current_slave = P2_LEG_ADDR; break;
                  case P2_LEG_ADDR: current_slave = P1_ARM_ADDR; break;
              }
              waiting_for_response = 0;
          }
      }

      /* --- SPI to FPGA: send player state, receive sound flags --- */
      {
          uint8_t txDataP1[2] = {0};
          uint8_t txDataP2[2] = {0};
          uint8_t rxData[2]   = {0};

          txDataP1[0] = 0xA1;
          txDataP1[1] = ((p1_joystick_val & 0x03) << 6) |
                        ((p1_jump         & 0x01) << 5) |
                        ((p1_punch        & 0x01) << 4) |
                        ((p1_emg_val      & 0x01) << 3);
          SPI_TransmitReceive(txDataP1, rxData, 2);

          txDataP2[0] = 0xA2;
          txDataP2[1] = ((p2_joystick_val & 0x03) << 6) |
                        ((p2_jump         & 0x01) << 5) |
                        ((p2_punch        & 0x01) << 4) |
                        ((p2_emg_val      & 0x01) << 3);
          SPI_TransmitReceive(txDataP2, rxData, 2);

          /* Decode game state from FPGA response */
          p2_got_hit      = (rxData[0] >> 7) & 0x01;
          p1_got_hit      = (rxData[0] >> 6) & 0x01;
          p1_win          = (rxData[0] >> 5) & 0x01;
          p2_win          = (rxData[0] >> 4) & 0x01;
          p1_jump_snd     = (rxData[0] >> 3) & 0x01;
          p2_jump_snd     = (rxData[0] >> 2) & 0x01;
          p1_punch_snd    = (rxData[0] >> 1) & 0x01;
          p2_punch_snd    = (rxData[0] >> 0) & 0x01;
          p1_charging_snd = (rxData[1] >> 7) & 0x01;
          p2_charging_snd = (rxData[1] >> 6) & 0x01;
          uint8_t timesup_snd = (rxData[1] >> 3) & 0x01;

          /* Map FPGA sound flags → audio event flags */
          if (p1_punch_snd) p1_punch_flag = 1;
          if (p2_punch_snd) p2_punch_flag = 1;
          if (p1_jump_snd)  p1_jump_flag  = 1;
          if (p2_jump_snd)  p2_jump_flag  = 1;
          if (timesup_snd && bgm_state < 2)  timesup_flag  = 1;
          /* 2-bit game state from FPGA: rxData[1] bits 5:4
           * 0 = intro, 1 = game running, 2 = game over */
          uint8_t fpga_game_state = (rxData[1] >> 4) & 0x03;
          if (fpga_game_state != game_started) {
              if (fpga_game_state == 0) {
                  /* Game over → intro reset: switch BGM back to intro */
                  pending_bgm_file   = BGM_INTRO;
                  bgm_switch_pending = 1;
                  bgm_state          = 0;
              } else if (fpga_game_state == 1) {
                  /* Intro → game: play ready, BGM switch deferred until ready finishes */
                  game_countdown_flag = 1;
                  pending_bgm_file    = BGM_GAME;
                  bgm_switch_pending  = 1;
                  bgm_state           = 1;
              } else if (fpga_game_state == 2) {
                  /* Game running → game over */
                  game_over_flag = 1;
              }
              game_started = fpga_game_state;
          }
      }

      /* --- Countdown: play "ready", BGM switches after it finishes --- */
      if (game_countdown_flag) {
          game_countdown_flag = 0;
          Play_SFX(ready, sizeof(ready) / sizeof(ready[0]));
      }
      if (bgm_switch_pending) {
          do_bgm_switch();
      }

      /* --- Game over: play youwin → perfect, then switch BGM --- */
      if (game_over_flag) {
          game_over_flag     = 0;
          bgm_state          = 2;
          pending_bgm_file   = BGM_GAMEOVER;
          bgm_switch_pending = 1;
          Play_SFX(youwin, sizeof(youwin) / sizeof(youwin[0]));
          Queue_SFX(perfect, sizeof(perfect) / sizeof(perfect[0]));
      }

      /* --- SFX triggers (consume and clear flags) --- */
      if (p1_punch_flag || p2_punch_flag) {
          p1_punch_flag = 0;
          p2_punch_flag = 0;
          Play_SFX(punch, sizeof(punch) / sizeof(punch[0]));
          if (p1_got_hit || p2_got_hit)
              Queue_SFX(pain, sizeof(pain) / sizeof(pain[0]));
      }
      if (p1_jump_flag || p2_jump_flag) {
          p1_jump_flag = 0;
          p2_jump_flag = 0;
          Play_SFX(jump2, sizeof(jump2) / sizeof(jump2[0]));
      }
      if (p1_charging_snd || p2_charging_snd) {
          Play_SFX_Gain(powerup, sizeof(powerup) / sizeof(powerup[0]), 3);
      }
      if (timesup_flag) {
          timesup_flag       = 0;
          bgm_state          = 3;
          pending_bgm_file   = BGM_GAMEOVER;
          bgm_switch_pending = 1;
          Play_SFX(timeup, sizeof(timeup) / sizeof(timeup[0]));
      }

      /* --- BGM streaming --- */
      if (!playing) {
          start_wav_playback();
      }
      if (half_ready) {
          half_ready = 0;
          fill_output(&audio_out[0], HALF_BUF_SAMPLES);
      }
      if (full_ready) {
          full_ready = 0;
          fill_output(&audio_out[HALF_BUF_SAMPLES], HALF_BUF_SAMPLES);
      }
   //p1_jump_flag = 0;
   //p1_punch_flag = 1;
    // game_started = 1;
    // HAL_Delay(20000)

    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  if (HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_MSI;
  RCC_OscInitStruct.MSIState = RCC_MSI_ON;
  RCC_OscInitStruct.MSICalibrationValue = 0;
  RCC_OscInitStruct.MSIClockRange = RCC_MSIRANGE_6;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_MSI;
  RCC_OscInitStruct.PLL.PLLM = 1;
  RCC_OscInitStruct.PLL.PLLN = 40;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
  RCC_OscInitStruct.PLL.PLLQ = RCC_PLLQ_DIV2;
  RCC_OscInitStruct.PLL.PLLR = RCC_PLLR_DIV2;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_3) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief DAC1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_DAC1_Init(void)
{

  /* USER CODE BEGIN DAC1_Init 0 */

  /* USER CODE END DAC1_Init 0 */

  DAC_ChannelConfTypeDef sConfig = {0};

  /* USER CODE BEGIN DAC1_Init 1 */

  /* USER CODE END DAC1_Init 1 */

  /** DAC Initialization
  */
  hdac1.Instance = DAC1;
  if (HAL_DAC_Init(&hdac1) != HAL_OK)
  {
    Error_Handler();
  }

  /** DAC channel OUT1 config
  */
  sConfig.DAC_SampleAndHold = DAC_SAMPLEANDHOLD_DISABLE;
  sConfig.DAC_Trigger = DAC_TRIGGER_T2_TRGO;
  sConfig.DAC_HighFrequency = DAC_HIGH_FREQUENCY_INTERFACE_MODE_ABOVE_80MHZ;
  sConfig.DAC_OutputBuffer = DAC_OUTPUTBUFFER_ENABLE;
  sConfig.DAC_ConnectOnChipPeripheral = DAC_CHIPCONNECT_DISABLE;
  sConfig.DAC_UserTrimming = DAC_TRIMMING_FACTORY;
  if (HAL_DAC_ConfigChannel(&hdac1, &sConfig, DAC_CHANNEL_1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN DAC1_Init 2 */

  /* USER CODE END DAC1_Init 2 */

}

/**
  * @brief LPUART1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_LPUART1_UART_Init(void)
{

  /* USER CODE BEGIN LPUART1_Init 0 */

  /* USER CODE END LPUART1_Init 0 */

  /* USER CODE BEGIN LPUART1_Init 1 */

  /* USER CODE END LPUART1_Init 1 */
  hlpuart1.Instance = LPUART1;
  hlpuart1.Init.BaudRate = 115200;
  hlpuart1.Init.WordLength = UART_WORDLENGTH_8B;
  hlpuart1.Init.StopBits = UART_STOPBITS_1;
  hlpuart1.Init.Parity = UART_PARITY_NONE;
  hlpuart1.Init.Mode = UART_MODE_TX_RX;
  hlpuart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  hlpuart1.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  hlpuart1.Init.ClockPrescaler = UART_PRESCALER_DIV1;
  hlpuart1.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  hlpuart1.FifoMode = UART_FIFOMODE_DISABLE;
  if (HAL_UART_Init(&hlpuart1) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetTxFifoThreshold(&hlpuart1, UART_TXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetRxFifoThreshold(&hlpuart1, UART_RXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_DisableFifoMode(&hlpuart1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN LPUART1_Init 2 */

  /* USER CODE END LPUART1_Init 2 */

}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{

  /* USER CODE BEGIN USART2_Init 0 */

  /* USER CODE END USART2_Init 0 */

  /* USER CODE BEGIN USART2_Init 1 */

  /* USER CODE END USART2_Init 1 */
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 9600;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  huart2.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart2.Init.ClockPrescaler = UART_PRESCALER_DIV1;
  huart2.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetTxFifoThreshold(&huart2, UART_TXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetRxFifoThreshold(&huart2, UART_RXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_DisableFifoMode(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART2_Init 2 */

  /* USER CODE END USART2_Init 2 */

}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_256;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 7;
  hspi1.Init.CRCLength = SPI_CRC_LENGTH_DATASIZE;
  hspi1.Init.NSSPMode = SPI_NSS_PULSE_ENABLE;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief SPI2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI2_Init(void)
{

  /* USER CODE BEGIN SPI2_Init 0 */

  /* USER CODE END SPI2_Init 0 */

  /* USER CODE BEGIN SPI2_Init 1 */

  /* USER CODE END SPI2_Init 1 */
  /* SPI2 parameter configuration*/
  hspi2.Instance = SPI2;
  hspi2.Init.Mode = SPI_MODE_MASTER;
  hspi2.Init.Direction = SPI_DIRECTION_2LINES;
  hspi2.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi2.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi2.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi2.Init.NSS = SPI_NSS_SOFT;
  hspi2.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_16;
  hspi2.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi2.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi2.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi2.Init.CRCPolynomial = 7;
  hspi2.Init.CRCLength = SPI_CRC_LENGTH_DATASIZE;
  hspi2.Init.NSSPMode = SPI_NSS_PULSE_ENABLE;
  if (HAL_SPI_Init(&hspi2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI2_Init 2 */

  /* USER CODE END SPI2_Init 2 */

}

/**
  * @brief TIM2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM2_Init(void)
{

  /* USER CODE BEGIN TIM2_Init 0 */

  /* USER CODE END TIM2_Init 0 */

  TIM_ClockConfigTypeDef sClockSourceConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM2_Init 1 */

  /* USER CODE END TIM2_Init 1 */
  htim2.Instance = TIM2;
  htim2.Init.Prescaler = 0;
  htim2.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim2.Init.Period = 4999;
  htim2.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim2.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_Base_Init(&htim2) != HAL_OK)
  {
    Error_Handler();
  }
  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim2, &sClockSourceConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_UPDATE;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim2, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM2_Init 2 */

  /* USER CODE END TIM2_Init 2 */

}

/**
  * Enable DMA controller clock
  */
static void MX_DMA_Init(void)
{

  /* DMA controller clock enable */
  __HAL_RCC_DMAMUX1_CLK_ENABLE();
  __HAL_RCC_DMA1_CLK_ENABLE();

  /* DMA interrupt init */
  /* DMA1_Channel1_IRQn interrupt configuration */
  HAL_NVIC_SetPriority(DMA1_Channel1_IRQn, 0, 0);
  HAL_NVIC_EnableIRQ(DMA1_Channel1_IRQn);
  /* DMA1_Channel2_IRQn interrupt configuration */
  HAL_NVIC_SetPriority(DMA1_Channel2_IRQn, 0, 0);
  HAL_NVIC_EnableIRQ(DMA1_Channel2_IRQn);

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOE_CLK_ENABLE();
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOF_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();
  __HAL_RCC_GPIOG_CLK_ENABLE();
  HAL_PWREx_EnableVddIO2();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOE, GPIO_PIN_4, GPIO_PIN_SET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOF, GPIO_PIN_12, GPIO_PIN_SET);

  /*Configure GPIO pins : PE2 PE3 */
  GPIO_InitStruct.Pin = GPIO_PIN_2|GPIO_PIN_3;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF13_SAI1;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /*Configure GPIO pin : PE4 */
  GPIO_InitStruct.Pin = GPIO_PIN_4;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /*Configure GPIO pins : PF0 PF1 PF2 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_2;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_OD;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF4_I2C2;
  HAL_GPIO_Init(GPIOF, &GPIO_InitStruct);

  /*Configure GPIO pin : PF7 */
  GPIO_InitStruct.Pin = GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF13_SAI1;
  HAL_GPIO_Init(GPIOF, &GPIO_InitStruct);

  /*Configure GPIO pins : PC0 PC1 PC3 PC4
                           PC5 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_3|GPIO_PIN_4
                          |GPIO_PIN_5;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG_ADC_CONTROL;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pins : PA1 PA3 */
  GPIO_InitStruct.Pin = GPIO_PIN_1|GPIO_PIN_3;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG_ADC_CONTROL;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pin : PB0 */
  GPIO_InitStruct.Pin = GPIO_PIN_0;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF2_TIM3;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pin : PB1 */
  GPIO_InitStruct.Pin = GPIO_PIN_1;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG_ADC_CONTROL;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pins : PB2 PB6 */
  GPIO_InitStruct.Pin = GPIO_PIN_2|GPIO_PIN_6;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pin : PF12 */
  GPIO_InitStruct.Pin = GPIO_PIN_12;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOF, &GPIO_InitStruct);

  /*Configure GPIO pins : PE7 PE8 PE9 PE10
                           PE11 PE12 PE13 */
  GPIO_InitStruct.Pin = GPIO_PIN_7|GPIO_PIN_8|GPIO_PIN_9|GPIO_PIN_10
                          |GPIO_PIN_11|GPIO_PIN_12|GPIO_PIN_13;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF1_TIM1;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /*Configure GPIO pins : PE14 PE15 */
  GPIO_InitStruct.Pin = GPIO_PIN_14|GPIO_PIN_15;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF3_TIM1_COMP1;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /*Configure GPIO pins : PB12 PB13 PB15 */
  GPIO_InitStruct.Pin = GPIO_PIN_12|GPIO_PIN_13|GPIO_PIN_15;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF13_SAI2;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pin : PB14 */
  GPIO_InitStruct.Pin = GPIO_PIN_14;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF14_TIM15;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pins : PD8 PD9 */
  GPIO_InitStruct.Pin = GPIO_PIN_8|GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF7_USART3;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /*Configure GPIO pins : PD14 PD15 */
  GPIO_InitStruct.Pin = GPIO_PIN_14|GPIO_PIN_15;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF2_TIM4;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /*Configure GPIO pin : PC6 */
  GPIO_InitStruct.Pin = GPIO_PIN_6;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF13_SAI2;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pin : PC7 */
  GPIO_InitStruct.Pin = GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF2_TIM3;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pins : PC8 PC9 PC10 PC11
                           PC12 */
  GPIO_InitStruct.Pin = GPIO_PIN_8|GPIO_PIN_9|GPIO_PIN_10|GPIO_PIN_11
                          |GPIO_PIN_12;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF12_SDMMC1;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pins : PA8 PA10 */
  GPIO_InitStruct.Pin = GPIO_PIN_8|GPIO_PIN_10;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF10_OTG_FS;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pin : PA9 */
  GPIO_InitStruct.Pin = GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pin : PD0 */
  GPIO_InitStruct.Pin = GPIO_PIN_0;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF9_CAN1;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /*Configure GPIO pin : PD2 */
  GPIO_InitStruct.Pin = GPIO_PIN_2;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF12_SDMMC1;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /*Configure GPIO pins : PB3 PB4 PB5 */
  GPIO_InitStruct.Pin = GPIO_PIN_3|GPIO_PIN_4|GPIO_PIN_5;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF6_SPI3;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pins : PB8 PB9 */
  GPIO_InitStruct.Pin = GPIO_PIN_8|GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_OD;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF4_I2C1;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pin : PE0 */
  GPIO_InitStruct.Pin = GPIO_PIN_0;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF2_TIM4;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
#ifdef __GNUC__
#define PUTCHAR_PROTOTYPE int __io_putchar(int ch)
#else
  #define PUTCHAR_PROTOTYPE int fputc(int ch, FILE *f)
#endif /* __GNUC__ */
PUTCHAR_PROTOTYPE
{
  HAL_UART_Transmit(&hlpuart1, (uint8_t *)&ch, 1, 0xFFFF);
  return ch;
}

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
