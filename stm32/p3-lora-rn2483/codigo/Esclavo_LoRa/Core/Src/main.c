/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
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

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "ssd1351.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
/* === LoRa / UART3 helpers (RX por líneas con polling suave) === */
static int LORA_SendLine(const char *line, uint32_t timeout_ms)
{
  extern UART_HandleTypeDef huart3;
  char tx[64];
  int n = snprintf(tx, sizeof(tx), "%s\r\n", line);
  if (n <= 0) return -1;
  if (HAL_UART_Transmit(&huart3, (uint8_t*)tx, (uint16_t)n, timeout_ms) != HAL_OK) return -2;
  return 0;
}

static int LORA_ReadLine(char *out, size_t out_sz, uint32_t timeout_ms)
{
  extern UART_HandleTypeDef huart3;
  size_t idx = 0;
  uint8_t ch;
  uint32_t start = HAL_GetTick();
  while ((HAL_GetTick() - start) < timeout_ms && idx < (out_sz - 1))
  {
    if (HAL_UART_Receive(&huart3, &ch, 1, 10) == HAL_OK)
    {
      if (ch == '\n') break;
      if (ch != '\r') out[idx++] = ch;
    }
  }
  out[idx] = '\0';
  return (idx > 0) ? (int)idx : -1;
}

/* === Misma PHY que el maestro y quedar escuchando === */
static int LORA_InitAndListen(void)
{
  char resp[96];
  /* Al comienzo de LORA_InitAndListen() */
  LORA_SendLine("mac pause", 200);

  if (LORA_ReadLine(resp, sizeof(resp), 500) < 0) return -1;
  /* Suele devolver "4294967295", cualquier línea es suficiente aquí */


  // reset RN por tu pin PE10 (en tu maestro ya tienes helper; aquí asumimos que lo haces antes)
  // Si quieres el pulso aquí, crea una función como en el maestro y llámala.


  // parámetros de LoRa idénticos al maestro
  LORA_SendLine("radio set mod lora", 200);              LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set freq 433000000", 200);        LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set pwr 14", 200);                LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set sf sf7", 200);                LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set bw 125", 200);                LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set cr 4/5", 200);                LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set crc on", 200);                LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set iqi off", 200);               LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set prlen 8", 200);               LORA_ReadLine(resp, sizeof(resp), 300);
  LORA_SendLine("radio set wdt 0", 200);  // DEBUG: cada 5 s, si no hay paquetes, RN devuelve "radio_err"
                LORA_ReadLine(resp, sizeof(resp), 300);

  // poner a escuchar
  if (LORA_SendLine("radio rx 0", 200) != 0) return -1;
  if (LORA_ReadLine(resp, sizeof(resp), 500) < 0) return -2; // "ok"
  HAL_Delay(20); // evita "busy"
  return 0;
}

/* === Conversión HEX4 -> int16_t (complemento a dos) === */



static inline void LORA_Reset_Pulse(void)
{
  HAL_GPIO_WritePin(RST_LoRa_GPIO_Port, RST_LoRa_Pin, GPIO_PIN_RESET); // PE10 low
  HAL_Delay(10);
  HAL_GPIO_WritePin(RST_LoRa_GPIO_Port, RST_LoRa_Pin, GPIO_PIN_SET);   // PE10 high
  HAL_Delay(300);
}


/* === Mostrar valor en OLED (HEX y decimal) === */


// Convierte 2 dígitos HEX ASCII (p.ej. "31") en un byte (0x31)
static int hex2_to_u8(const char *h, uint8_t *out)
{
  uint8_t v = 0;
  for (int i = 0; i < 2; i++) {
    char c = h[i];
    uint8_t d;
    if      (c >= '0' && c <= '9') d = (uint8_t)(c - '0');
    else if (c >= 'A' && c <= 'F') d = (uint8_t)(10 + (c - 'A'));
    else if (c >= 'a' && c <= 'f') d = (uint8_t)(10 + (c - 'a'));
    else return -1;
    v = (uint8_t)((v << 4) | d);
  }
  *out = v;
  return 0;
}

static void OLED_ShowLastDigit(char c)
{
  // etiqueta y valor en zona libre (ajusta si quieres)
  SSD1351_DrawText(20, 66, "D:", 0xFFFF, 0x0000, 2);
  char s[2] = { c, '\0' };
  SSD1351_DrawText(50, 66, s, 0xFFE0, 0x0000, 2); // “amarillo”
}




/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
SPI_HandleTypeDef hspi1;

UART_HandleTypeDef huart3;

/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART3_UART_Init(void);
static void MX_SPI1_Init(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

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
  MX_USART3_UART_Init();
  MX_SPI1_Init();
  /* USER CODE BEGIN 2 */
  HAL_GPIO_WritePin(GPIOD, EN_OLED_Pin, GPIO_PIN_SET);
  /* después de MX_GPIO_Init(); */
  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12, GPIO_PIN_RESET);

  /* === OLED ON === */
  SSD1351_Init();
  SSD1351_Clear();
  // Test de pantalla sólida

  SSD1351_DrawText(20, 0, "OLED OK", 0xFFFF, 0x0000, 2);

  /* === LoRa en escucha === */

  {
    char rx[64] = {0};
    SSD1351_DrawText(20, 36, "Probe RN...", 0xFFFF, 0x0000, 1);

    LORA_Reset_Pulse();              // reset con 300ms
    LORA_SendLine("sys get ver", 500);

    if (LORA_ReadLine(rx, sizeof(rx), 1500) > 0) {
      SSD1351_DrawText(0, 52, "RN OK:", 0x07E0, 0x0000, 1);
      SSD1351_DrawText(40, 52, rx, 0x07E0, 0x0000, 1); // típico: "RN2483 x.y.z ..."
    } else {
      SSD1351_DrawText(0, 72, "NO UART RN", 0xF800, 0x0000, 1);
      while (1) { HAL_Delay(1000); } // detener: arregla pins/MSP/RTS antes de seguir
    }
  }


  if (LORA_InitAndListen() == 0) {
    SSD1351_DrawText(20, 16, "LoRa RX OK", 0x07E0, 0x0000, 1);
  } else {
    SSD1351_DrawText(20, 16, "LoRa FAIL",  0xF800, 0x0000, 1);
  }
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
	  char line[96];

	  if (LORA_ReadLine(line, sizeof(line), 1000) > 0) {

	    // (opcional) debug: muestra lo último que dijo el RN
	    SSD1351_DrawText(0, 80, "RN:                         ", 0xFFFF, 0x0000, 1);
	    SSD1351_DrawText(20, 80, line, 0xFFFF, 0x0000, 1);

	    if (strncmp(line, "radio_rx ", 9) == 0) {
	      const char *p = line + 9;
	      while (*p == ' ') p++; // saltar espacios

	      // --- tomar SOLO los 2 primeros hex del payload ---
	      char hex2[3] = {0};
	      if (isxdigit((unsigned char)p[0]) && isxdigit((unsigned char)p[1])) {
	        hex2[0] = p[0];
	        hex2[1] = p[1];

	        uint8_t b;
	        if (hex2_to_u8(hex2, &b) == 0) {
	          char to_show;

	          // Si el Maestro manda ASCII '0'..'9' -> 0x30..0x39
	          if (b >= '0' && b <= '9') {
	            to_show = (char)b;
	          } else if (b <= 9) {           // si algún día mandas 00..09 crudo
	            to_show = (char)('0' + b);
	          } else {
	            to_show = '.';               // cualquier otro valor
	          }

	          OLED_ShowLastDigit(to_show);   // <-- pinta el dígito (no “30/31”)
	          HAL_GPIO_TogglePin(GPIOD, LD4_Pin); // LED verde feedback
	        }
	      }

	      // volver a escuchar
	      LORA_SendLine("radio rx 0", 200);
	      LORA_ReadLine(line, sizeof(line), 500); // "ok"
	      HAL_Delay(20);
	    }
	    else if (!strcmp(line, "radio_err") || !strcmp(line, "busy")) {
	      LORA_SendLine("radio rx 0", 200);
	      LORA_ReadLine(line, sizeof(line), 500);
	      HAL_Delay(20);
	    }
	  }
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
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLM = 8;
  RCC_OscInitStruct.PLL.PLLN = 50;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV4;
  RCC_OscInitStruct.PLL.PLLQ = 7;
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
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_0) != HAL_OK)
  {
    Error_Handler();
  }
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
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_8;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 10;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief USART3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART3_UART_Init(void)
{

  /* USER CODE BEGIN USART3_Init 0 */

  /* USER CODE END USART3_Init 0 */

  /* USER CODE BEGIN USART3_Init 1 */

  /* USER CODE END USART3_Init 1 */
  huart3.Instance = USART3;
  huart3.Init.BaudRate = 57600;
  huart3.Init.WordLength = UART_WORDLENGTH_8B;
  huart3.Init.StopBits = UART_STOPBITS_1;
  huart3.Init.Parity = UART_PARITY_NONE;
  huart3.Init.Mode = UART_MODE_TX_RX;
  huart3.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart3.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART3_Init 2 */

  /* USER CODE END USART3_Init 2 */

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
  __HAL_RCC_GPIOB_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOE, CS_I2C_SPI_Pin|RES_OLED_Pin|CS_OLED_Pin|RST_LoRa_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(OTG_FS_PowerSwitchOn_GPIO_Port, OTG_FS_PowerSwitchOn_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(RW_OLED_GPIO_Port, RW_OLED_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOB, DC_OLED_Pin|RTS_LoRa_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOD, LD4_Pin|LD3_Pin|LD5_Pin|LD6_Pin
                          |EN_OLED_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pins : CS_I2C_SPI_Pin RES_OLED_Pin CS_OLED_Pin */
  GPIO_InitStruct.Pin = CS_I2C_SPI_Pin|RES_OLED_Pin|CS_OLED_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /*Configure GPIO pins : OTG_FS_PowerSwitchOn_Pin RW_OLED_Pin */
  GPIO_InitStruct.Pin = OTG_FS_PowerSwitchOn_Pin|RW_OLED_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pins : DC_OLED_Pin RTS_LoRa_Pin */
  GPIO_InitStruct.Pin = DC_OLED_Pin|RTS_LoRa_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pin : BOOT1_Pin */
  GPIO_InitStruct.Pin = BOOT1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(BOOT1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : RST_LoRa_Pin */
  GPIO_InitStruct.Pin = RST_LoRa_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(RST_LoRa_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pins : LD4_Pin LD3_Pin LD5_Pin LD6_Pin
                           EN_OLED_Pin */
  GPIO_InitStruct.Pin = LD4_Pin|LD3_Pin|LD5_Pin|LD6_Pin
                          |EN_OLED_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */
  /* PB12 como salida: mantenerlo en estado "listo" */
  GPIO_InitStruct.Pin = GPIO_PIN_12;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;    // evita flotar
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12, GPIO_PIN_RESET);

  GPIO_InitStruct.Pin = GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

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
