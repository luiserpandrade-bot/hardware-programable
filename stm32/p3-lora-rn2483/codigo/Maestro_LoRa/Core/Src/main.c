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
#include "usb_host.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdio.h>
#include <string.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
TIM_HandleTypeDef htim3;

UART_HandleTypeDef huart3;

/* USER CODE BEGIN PV */
// ==== Config TLI4970 (SPI1 + CS en PE5) ====
//static int16_t g_i_last = 0;   // último muestreo de corriente


// Buffers LoRa
//#define LORA_RX_BUF_SZ 256
//static uint8_t lora_rx_buf[LORA_RX_BUF_SZ];
//static volatile size_t lora_rx_len = 0;
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART3_UART_Init(void);
static void MX_TIM3_Init(void);
void MX_USB_HOST_Process(void);

/* USER CODE BEGIN PFP */


/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
static inline void LORA_Reset_Pulse(void)
{
  // RST PE10: Low 10 ms, luego High
  HAL_GPIO_WritePin(GPIOE, GPIO_PIN_10, GPIO_PIN_RESET);
  HAL_Delay(10);
  HAL_GPIO_WritePin(GPIOE, GPIO_PIN_10, GPIO_PIN_SET);
  HAL_Delay(100); // esperar banner de inicio
}


// Convierte 1 byte a 2 dígitos HEX ASCII (ej. 0x31 -> "31")
static void u8_to_hex2(uint8_t b, char out[3]) {
  const char *H = "0123456789ABCDEF";
  out[0] = H[(b >> 4) & 0x0F];
  out[1] = H[b & 0x0F];
  out[2] = '\0';
}


// === LoRa: TX/RX por polling línea-a-línea ===
static int LORA_SendLine(const char *line, uint32_t timeout_ms)
{
  char tx[128];
  int n = snprintf(tx, sizeof(tx), "%s\r\n", line);
  if (n <= 0) return -1;
  if (HAL_UART_Transmit(&huart3, (uint8_t*)tx, (uint16_t)n, timeout_ms) != HAL_OK) return -2;
  return 0;
}

static int LORA_ReadLine(char *out, size_t out_sz, uint32_t timeout_ms)
{
  size_t idx = 0;
  uint8_t ch;
  uint32_t start = HAL_GetTick();
  while ((HAL_GetTick() - start) < timeout_ms && idx < (out_sz-1))
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

static int LORA_BootAndCheck(void)
{
  char line[128];

  LORA_Reset_Pulse();

  // Algunos RN2483 envían un banner tras reset; intenta leerlo sin bloquearte mucho
  LORA_ReadLine(line, sizeof(line), 300);

  if (LORA_SendLine("sys get ver", 200) != 0) return -1;
  if (LORA_ReadLine(line, sizeof(line), 500) < 0) return -2;

  // Aquí podrías validar prefijo "RN"
  return 0;
}

// === LoRa: TX básico en modo 'radio' (punto a punto) ===
static int LORA_RadioBasicTx(const char *hex_payload)
{
  char cmd[64], resp[64];


  LORA_SendLine("mac pause", 200);
  LORA_ReadLine(resp, sizeof(resp), 500);   // suele devolver "4294967295"

  // Config LoRa básica @433 MHz
  LORA_SendLine("radio set mod lora", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  LORA_SendLine("radio set freq 433000000", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  LORA_SendLine("radio set pwr 14", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  LORA_SendLine("radio set sf sf7", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  // BW correcto para LoRa (125/250/500)
  LORA_SendLine("radio set bw 125", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  // Coding rate (4/5..4/8), CRC on, IQ invert off, preamble 8 (ajustables)
  LORA_SendLine("radio set cr 4/5", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  LORA_SendLine("radio set crc on", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  LORA_SendLine("radio set iqi off", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  LORA_SendLine("radio set prlen 8", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  // WDT 0 para evitar timeouts en radio
  LORA_SendLine("radio set wdt 0", 200);
  LORA_ReadLine(resp, sizeof(resp), 300);

  // TX
  snprintf(cmd, sizeof(cmd), "radio tx %s", hex_payload);
  if (LORA_SendLine(cmd, 500) != 0) return -1;

  if (LORA_ReadLine(resp, sizeof(resp), 500) < 0) return -2;   // esperado: "ok"
  if (LORA_ReadLine(resp, sizeof(resp), 2000) < 0) return -3;  // esperado: "radio_tx_ok"
  return 0;
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
  MX_USB_HOST_Init();
  MX_USART3_UART_Init();
  MX_TIM3_Init();
  /* USER CODE BEGIN 2 */


  // Boot + versión del LoRa
  if (LORA_BootAndCheck() != 0) {
    // aquí puedes encender un LED o imprimir por otra UART para saber que falló
  }

  // Arrancar PWM con 20% (ejemplo)

  //uint8_t txData[100];
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */
    MX_USB_HOST_Process();

    /* USER CODE BEGIN 3 */
	      static uint8_t dig = 0;        // dígito actual (0..9)
	      static uint32_t t_tx = 0;

	      if (HAL_GetTick() - t_tx >= 1000)   // cada 1 segundo
	      {
	        t_tx = HAL_GetTick();

	        char payload_hex[3];              // 2 hex + '\0'
	        uint8_t ascii_digit = (uint8_t)('0' + dig); // '0'..'9'
	        u8_to_hex2(ascii_digit, payload_hex);       // ej. '1' -> "31"

	        int r = LORA_RadioBasicTx(payload_hex);     // envía "radio tx 31"
	        if (r == 0) {
	          HAL_GPIO_TogglePin(GPIOD, GPIO_PIN_12);   // LED verde: TX OK
	        } else {
	          HAL_GPIO_WritePin(GPIOD, GPIO_PIN_14, GPIO_PIN_SET); // LED rojo: fallo
	        }

	        // avanza al siguiente dígito
	        dig++;
	        if (dig > 9) dig = 0;
	      }
    }
  }
  /* USER CODE END 3 */

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
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLM = 8;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
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

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_5) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief TIM3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM3_Init(void)
{

  /* USER CODE BEGIN TIM3_Init 0 */

  /* USER CODE END TIM3_Init 0 */

  TIM_ClockConfigTypeDef sClockSourceConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM3_Init 1 */

  /* USER CODE END TIM3_Init 1 */
  htim3.Instance = TIM3;
  htim3.Init.Prescaler = 0;
  htim3.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim3.Init.Period = 4199;
  htim3.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim3.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_Base_Init(&htim3) != HAL_OK)
  {
    Error_Handler();
  }
  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim3, &sClockSourceConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim3, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM3_Init 2 */

  /* USER CODE END TIM3_Init 2 */

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
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOE_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(OTG_FS_PowerSwitchOn_GPIO_Port, OTG_FS_PowerSwitchOn_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(LoRa_RST_GPIO_Port, LoRa_RST_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOD, LD4_Pin|LD3_Pin|LD5_Pin|LD6_Pin
                          |Audio_RST_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin : OTG_FS_PowerSwitchOn_Pin */
  GPIO_InitStruct.Pin = OTG_FS_PowerSwitchOn_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(OTG_FS_PowerSwitchOn_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : B1_Pin */
  GPIO_InitStruct.Pin = B1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_EVT_RISING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : LoRa_RST_Pin */
  GPIO_InitStruct.Pin = LoRa_RST_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(LoRa_RST_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pins : LD4_Pin LD3_Pin LD5_Pin LD6_Pin
                           Audio_RST_Pin */
  GPIO_InitStruct.Pin = LD4_Pin|LD3_Pin|LD5_Pin|LD6_Pin
                          |Audio_RST_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /*Configure GPIO pin : MEMS_INT2_Pin */
  GPIO_InitStruct.Pin = MEMS_INT2_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_EVT_RISING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(MEMS_INT2_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

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
