/* USER CODE BEGIN Header */
/**
******************************************************************************
 * @file    user_diskio.c
 * @brief   FatFs disk I/O driver implemented directly in this file for
 *          SPI microSD card access.
 ******************************************************************************
 */
 /* USER CODE END Header */

#ifdef USE_OBSOLETE_USER_CODE_SECTION_0
/*
 * Warning: the user section 0 is no more in use (starting from CubeMx version 4.16.0)
 * To be suppressed in the future.
 * Kept to ensure backward compatibility with previous CubeMx versions when
 * migrating projects.
 * User code previously added there should be copied in the new user sections before
 * the section contents can be deleted.
 */
/* USER CODE BEGIN 0 */
/* USER CODE END 0 */
#endif

/* USER CODE BEGIN DECL */
#include <string.h>
#include <stdio.h>
#include "ff_gen_drv.h"
#include "main.h"
extern SPI_HandleTypeDef hspi2;
//#include "spi.h"

/* Disk status */
static volatile DSTATUS Stat = STA_NOINIT;

/* ---------- SD SPI config ---------- */
#define SD_SPI_HANDLE           hspi2

/* CHANGE THESE IF YOUR GENERATED NAMES DIFFER */
#define SD_CS_PORT              GPIOE
#define SD_CS_PIN               GPIO_PIN_4

/* ---------- SD command set ---------- */
#define CMD0    (0x40 + 0)    // GO_IDLE_STATE
#define CMD1    (0x40 + 1)
#define CMD8    (0x40 + 8)    // SEND_IF_COND
#define CMD9    (0x40 + 9)    // SEND_CSD
#define CMD10   (0x40 + 10)
#define CMD12   (0x40 + 12)   // STOP_TRANSMISSION
#define CMD16   (0x40 + 16)   // SET_BLOCKLEN
#define CMD17   (0x40 + 17)   // READ_SINGLE_BLOCK
#define CMD18   (0x40 + 18)   // READ_MULTIPLE_BLOCK
#define CMD24   (0x40 + 24)
#define CMD25   (0x40 + 25)
#define CMD55   (0x40 + 55)   // APP_CMD
#define CMD58   (0x40 + 58)   // READ_OCR
#define ACMD41  (0x40 + 41)   // SD_SEND_OP_COND (after CMD55)

/* Card type flags */
#define CT_MMC      0x01
#define CT_SD1      0x02
#define CT_SD2      0x04
#define CT_BLOCK    0x08

static BYTE CardType = 0;

/* 512-byte dummy TX buffer for bulk block reads (filled with 0xFF in disk_initialize) */
static BYTE ff_dummy[512];

/* ---------- low-level helpers ---------- */

static void SD_CS_Low(void)
{
    HAL_GPIO_WritePin(SD_CS_PORT, SD_CS_PIN, GPIO_PIN_RESET);
}

static void SD_CS_High(void)
{
    HAL_GPIO_WritePin(SD_CS_PORT, SD_CS_PIN, GPIO_PIN_SET);
}

static BYTE SPI_TxRxByte(BYTE data)
{
    BYTE rx;
    HAL_SPI_TransmitReceive(&SD_SPI_HANDLE, &data, &rx, 1, HAL_MAX_DELAY);
    return rx;
}

static void SPI_RxBytePtr(BYTE *buff)
{
    *buff = SPI_TxRxByte(0xFF);
}

static void SPI_RxBuffer(BYTE *buff, UINT len)
{
    /* One HAL call for the whole block instead of one per byte.
       ff_dummy is pre-filled with 0xFF so the SD card sees valid idle bytes. */
    HAL_SPI_TransmitReceive(&SD_SPI_HANDLE, ff_dummy, buff, len, HAL_MAX_DELAY);
}

static void SPI_TxBuffer(const BYTE *buff, UINT len)
{
    for (UINT i = 0; i < len; i++) {
        SPI_TxRxByte(buff[i]);
    }
}

static void SD_SendDummyClocks(void)
{
    SD_CS_High();
    for (int i = 0; i < 10; i++) {
        SPI_TxRxByte(0xFF);   // 80 dummy clocks
    }
}

static int SD_WaitReady(uint32_t timeout_ms)
{
    uint32_t start = HAL_GetTick();
    BYTE resp;

    do {
        resp = SPI_TxRxByte(0xFF);
        if (resp == 0xFF) return 1;
    } while ((HAL_GetTick() - start) < timeout_ms);

    return 0;
}

static void SD_Deselect(void)
{
    SD_CS_High();
    SPI_TxRxByte(0xFF);
}

static int SD_Select(void)
{
    SD_CS_Low();
    SPI_TxRxByte(0xFF);

    if (SD_WaitReady(500)) return 1;

    printf("SD_Select: WaitReady timeout\r\n");
    SD_Deselect();
    return 0;
}

static BYTE SD_SendCmd(BYTE cmd, DWORD arg)
{
    BYTE crc, res;
    BYTE n;

    if (cmd == ACMD41) {
        res = SD_SendCmd(CMD55, 0);
        if (res > 1) return res;
    }

    SD_Deselect();
    if (!SD_Select()) return 0xFF;

    /* send command packet */
    SPI_TxRxByte(cmd);
    SPI_TxRxByte((BYTE)(arg >> 24));
    SPI_TxRxByte((BYTE)(arg >> 16));
    SPI_TxRxByte((BYTE)(arg >> 8));
    SPI_TxRxByte((BYTE)arg);

    crc = 0x01;
    if (cmd == CMD0) crc = 0x95;
    if (cmd == CMD8) crc = 0x87;
    SPI_TxRxByte(crc);

    /* Skip one byte for CMD12 */
    if (cmd == CMD12) SPI_TxRxByte(0xFF);

    /* wait for response */
    n = 10;
    do {
        res = SPI_TxRxByte(0xFF);
    } while ((res & 0x80) && --n);

    return res;
}

static int SD_RxDataBlock(BYTE *buff, UINT len)
{
    BYTE token;
    uint32_t start = HAL_GetTick();

    do {
        token = SPI_TxRxByte(0xFF);
        if (token == 0xFE) break;
    } while ((HAL_GetTick() - start) < 200);

    if (token != 0xFE) {
        printf("RxDataBlock timeout, last token=0x%02X\r\n", token);
        return 0;
    }

    SPI_RxBuffer(buff, len);

    /* discard CRC */
    SPI_TxRxByte(0xFF);
    SPI_TxRxByte(0xFF);

    return 1;
}

static DSTATUS SD_disk_initialize_internal(void)
{
    BYTE n, cmd, ty, ocr[4];

    ty = 0;

    memset(ff_dummy, 0xFF, sizeof(ff_dummy));

    /* 74+ dummy clocks with CS high — SD SPI init requirement */
    SD_SendDummyClocks();

    BYTE cmd0_resp = SD_SendCmd(CMD0, 0);
    printf("CMD0: 0x%02X\r\n", cmd0_resp);

    if (cmd0_resp == 1) {
        if (SD_SendCmd(CMD8, 0x1AA) == 1) {
            for (n = 0; n < 4; n++) ocr[n] = SPI_TxRxByte(0xFF);

            if (ocr[2] == 0x01 && ocr[3] == 0xAA) {
                uint32_t start = HAL_GetTick();
                while ((HAL_GetTick() - start) < 1000) {
                    if (SD_SendCmd(ACMD41, 1UL << 30) == 0) break;
                }

                if (SD_SendCmd(CMD58, 0) == 0) {
                    for (n = 0; n < 4; n++) ocr[n] = SPI_TxRxByte(0xFF);
                    ty = (ocr[0] & 0x40) ? (CT_SD2 | CT_BLOCK) : CT_SD2;
                }
            }
        } else {
            if (SD_SendCmd(ACMD41, 0) <= 1) {
                ty = CT_SD1;
                cmd = ACMD41;
            } else {
                ty = CT_MMC;
                cmd = CMD1;
            }

            uint32_t start = HAL_GetTick();
            while ((HAL_GetTick() - start) < 1000) {
                if (SD_SendCmd(cmd, 0) == 0) break;
            }

            if ((HAL_GetTick() - start) >= 1000 || SD_SendCmd(CMD16, 512) != 0) {
                ty = 0;
            }
        }
    }

    CardType = ty;
    SD_Deselect();

    if (ty) {
        Stat &= ~STA_NOINIT;
        printf("SD OK type=0x%02X\r\n", ty);
    } else {
        Stat = STA_NOINIT;
        printf("SD FAILED\r\n");
    }

    return Stat;
}

static DRESULT SD_disk_read_internal(BYTE *buff, DWORD sector, UINT count)
{
    if (!count) return RES_PARERR;
    if (Stat & STA_NOINIT) return RES_NOTRDY;

    if (!(CardType & CT_BLOCK)) {
        sector *= 512;
    }

    if (count == 1) {
        BYTE cmd17_resp = SD_SendCmd(CMD17, sector);
        printf("CMD17 resp: 0x%02X\r\n", cmd17_resp);
        if ((cmd17_resp == 0) && SD_RxDataBlock(buff, 512)) {
            count = 0;
        }
    } else {
        if (SD_SendCmd(CMD18, sector) == 0) {
            do {
                if (!SD_RxDataBlock(buff, 512)) break;
                buff += 512;
            } while (--count);

            SD_SendCmd(CMD12, 0);   // stop transmission
        }
    }

    SD_Deselect();
    return count ? RES_ERROR : RES_OK;
}

static DRESULT SD_disk_ioctl_internal(BYTE cmd, void *buff)
{
    if (Stat & STA_NOINIT) return RES_NOTRDY;

    switch (cmd) {
    case CTRL_SYNC:
        if (SD_Select()) {
            SD_Deselect();
            return RES_OK;
        }
        return RES_ERROR;

    case GET_SECTOR_SIZE:
        *(WORD*)buff = 512;
        return RES_OK;

    case GET_BLOCK_SIZE:
        *(DWORD*)buff = 1;
        return RES_OK;

    case GET_SECTOR_COUNT:
        /* optional: proper CSD parsing could go here
           for basic mount/open/read, many setups don't need it immediately */
        *(DWORD*)buff = 0;
        return RES_OK;

    default:
        return RES_PARERR;
    }
}
/* USER CODE END DECL */

/* Private function prototypes -----------------------------------------------*/
DSTATUS USER_initialize (BYTE pdrv);
DSTATUS USER_status (BYTE pdrv);
DRESULT USER_read (BYTE pdrv, BYTE *buff, DWORD sector, UINT count);
#if _USE_WRITE == 1
  DRESULT USER_write (BYTE pdrv, const BYTE *buff, DWORD sector, UINT count);
#endif /* _USE_WRITE == 1 */
#if _USE_IOCTL == 1
  DRESULT USER_ioctl (BYTE pdrv, BYTE cmd, void *buff);
#endif /* _USE_IOCTL == 1 */

Diskio_drvTypeDef  USER_Driver =
{
  USER_initialize,
  USER_status,
  USER_read,
#if  _USE_WRITE
  USER_write,
#endif  /* _USE_WRITE == 1 */
#if  _USE_IOCTL == 1
  USER_ioctl,
#endif /* _USE_IOCTL == 1 */
};

/* Private functions ---------------------------------------------------------*/

/**
  * @brief  Initializes a Drive
  * @param  pdrv: Physical drive number (0..)
  * @retval DSTATUS: Operation status
  */
DSTATUS USER_initialize (
	BYTE pdrv           /* Physical drive nmuber to identify the drive */
)
{
  /* USER CODE BEGIN INIT */
    (void)pdrv;
    return SD_disk_initialize_internal();

  /* USER CODE END INIT */
}

/**
  * @brief  Gets Disk Status
  * @param  pdrv: Physical drive number (0..)
  * @retval DSTATUS: Operation status
  */
DSTATUS USER_status (
	BYTE pdrv       /* Physical drive number to identify the drive */
)
{
  /* USER CODE BEGIN STATUS */
	(void)pdrv;
    return Stat;
  /* USER CODE END STATUS */
}

/**
  * @brief  Reads Sector(s)
  * @param  pdrv: Physical drive number (0..)
  * @param  *buff: Data buffer to store read data
  * @param  sector: Sector address (LBA)
  * @param  count: Number of sectors to read (1..128)
  * @retval DRESULT: Operation result
  */
DRESULT USER_read (
	BYTE pdrv,      /* Physical drive nmuber to identify the drive */
	BYTE *buff,     /* Data buffer to store read data */
	DWORD sector,   /* Sector address in LBA */
	UINT count      /* Number of sectors to read */
)
{
  /* USER CODE BEGIN READ */
	(void)pdrv;
	return SD_disk_read_internal(buff, sector, count);
  /* USER CODE END READ */
}

/**
  * @brief  Writes Sector(s)
  * @param  pdrv: Physical drive number (0..)
  * @param  *buff: Data to be written
  * @param  sector: Sector address (LBA)
  * @param  count: Number of sectors to write (1..128)
  * @retval DRESULT: Operation result
  */
#if _USE_WRITE == 1
DRESULT USER_write (
	BYTE pdrv,          /* Physical drive nmuber to identify the drive */
	const BYTE *buff,   /* Data to be written */
	DWORD sector,       /* Sector address in LBA */
	UINT count          /* Number of sectors to write */
)
{
  /* USER CODE BEGIN WRITE */
  /* USER CODE HERE */
    return RES_WRPRT;
  /* USER CODE END WRITE */
}
#endif /* _USE_WRITE == 1 */

/**
  * @brief  I/O control operation
  * @param  pdrv: Physical drive number (0..)
  * @param  cmd: Control code
  * @param  *buff: Buffer to send/receive control data
  * @retval DRESULT: Operation result
  */
#if _USE_IOCTL == 1
DRESULT USER_ioctl (
	BYTE pdrv,      /* Physical drive nmuber (0..) */
	BYTE cmd,       /* Control code */
	void *buff      /* Buffer to send/receive control data */
)
{
  /* USER CODE BEGIN IOCTL */
	(void)pdrv;
    return SD_disk_ioctl_internal(cmd, buff);
  /* USER CODE END IOCTL */
}
#endif /* _USE_IOCTL == 1 */

