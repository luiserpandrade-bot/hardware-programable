#ifndef __SSD1351_H__
#define __SSD1351_H__

#include "stm32f4xx_hal.h"
#include <stdint.h>

#define SSD1351_WIDTH  128
#define SSD1351_HEIGHT 128

void SSD1351_Init(void);
void SSD1351_Clear(void);
void SSD1351_DrawText(uint8_t x, uint8_t y, const char *text, uint16_t color, uint16_t bg, uint8_t scale);

#endif
