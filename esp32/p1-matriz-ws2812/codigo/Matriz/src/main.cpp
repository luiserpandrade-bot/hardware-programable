#include <Arduino.h>
// Matriz 16x16 WS2812 con ESP32 (FastLED)
// Data: GPIO4 por defecto. Cambia según tu conexión.

#include <FastLED.h>

#define MATRIX_WIDTH 16
#define MATRIX_HEIGHT 16
#define NUM_LEDS (MATRIX_WIDTH * MATRIX_HEIGHT)
#define DATA_PIN 4        // pin de datos al primer LED
#define BUTTON_PIN 2      // cambiar si usas diferente
#define BRIGHTNESS 120    // reducción para no sobrecargar la fuente

CRGB leds[NUM_LEDS];

// --- Configuración de modos / botones
volatile uint8_t mode = 0;
const uint8_t MODES = 5;
unsigned long lastButtonMillis = 0;
const unsigned long debounce = 200;

// --- Variables de control de modos (para reiniciar estado al cambiar de modo)
uint8_t prevMode = 255;
bool showHolaDone = false;

// --- Mapeo XY para matriz serpentina (zig-zag)
inline uint16_t XY(uint8_t x, uint8_t y){
  if(x >= MATRIX_WIDTH || y >= MATRIX_HEIGHT) return 0;
  if(y % 2 == 0) {
    // filas pares: izquierda -> derecha
    return (y * MATRIX_WIDTH) + (MATRIX_WIDTH - 1 - x);
  } else {
    // filas impares: derecha -> izquierda
    return (y * MATRIX_WIDTH) + x;
  }
}

// ----------------- Fuente 5x7 (mapa de bytes por carácter) -----------------
// Cada carácter tiene 5 columnas (cada byte = 7 bits vertical, LSB = top row).
// Fuente estándar simplificada (A-Z + espacio).
const uint8_t font5x7[][5] = {
  // A
  {0x7C,0x12,0x11,0x12,0x7C}, // A
  {0x7F,0x49,0x49,0x49,0x36}, // B
  {0x3E,0x41,0x41,0x41,0x22}, // C
  {0x7F,0x41,0x41,0x22,0x1C}, // D
  {0x7F,0x49,0x49,0x49,0x41}, // E
  {0x7F,0x09,0x09,0x09,0x01}, // F
  {0x3E,0x41,0x49,0x49,0x7A}, // G
  {0x7F,0x08,0x08,0x08,0x7F}, // H
  {0x00,0x41,0x7F,0x41,0x00}, // I
  {0x20,0x40,0x41,0x3F,0x01}, // J
  {0x7F,0x08,0x14,0x22,0x41}, // K
  {0x7F,0x40,0x40,0x40,0x40}, // L
  {0x7F,0x02,0x0C,0x02,0x7F}, // M
  {0x7F,0x04,0x08,0x10,0x7F}, // N
  {0x3E,0x41,0x41,0x41,0x3E}, // O
  {0x7F,0x09,0x09,0x09,0x06}, // P
  {0x3E,0x41,0x51,0x21,0x5E}, // Q
  {0x7F,0x09,0x19,0x29,0x46}, // R
  {0x46,0x49,0x49,0x49,0x31}, // S
  {0x01,0x01,0x7F,0x01,0x01}, // T
  {0x3F,0x40,0x40,0x40,0x3F}, // U
  {0x1F,0x20,0x40,0x20,0x1F}, // V
  {0x3F,0x40,0x38,0x40,0x3F}, // W
  {0x63,0x14,0x08,0x14,0x63}, // X
  {0x07,0x08,0x70,0x08,0x07}, // Y
  {0x61,0x51,0x49,0x45,0x43}, // Z
  {0x00,0x00,0x00,0x00,0x00}  // espacio (index 26)
};
// helpers para índice del caracter
inline int fontIndex(char c){
  if(c >= 'A' && c <= 'Z') return c - 'A';
  if(c == ' ') return 26;
  // si no reconocido, devolver espacio
  return 26;
}

// --- Efectos originales (sin tocar mucho)
void rainbowChase(uint8_t wait){
  static uint8_t startHue = 0;
  for(uint8_t y=0;y<MATRIX_HEIGHT;y++){
    for(uint8_t x=0;x<MATRIX_WIDTH;x++){
      uint16_t i = XY(x,y);
      uint8_t hue = startHue + (x*8) + (y*4);
      leds[i] = CHSV(hue, 200, 255);
    }
  }
  startHue += 1;
  FastLED.show();
  delay(wait);
}

void plasma(uint8_t t){
  static uint16_t count = 0;
  for(uint8_t y=0;y<MATRIX_HEIGHT;y++){
    for(uint8_t x=0;x<MATRIX_WIDTH;x++){
      float v = sinf((x+count)/4.0f) + sinf((y-count)/3.0f) + sinf((x+y+count)/5.0f);
      uint8_t hue = (uint8_t)map((int)((v+3.0f)*40.0f), 0, 240, 0, 255);
      leds[XY(x,y)] = CHSV(hue, 220, 200);
    }
  }
  count += t;
  FastLED.show();
  delay(20);
}

void fireworks(){
  static CRGB fade[NUM_LEDS];
  // decay: 250 es rápido, 200 es más lento (más fácil de ver)
  const uint8_t decay = 200;
  for(int i=0;i<NUM_LEDS;i++){
    fade[i].nscale8(decay); // reduce brillo de cada frame
  }

  // frecuencia de nuevas explosiones: 0..spawnRate-1, si ==0 -> explota
  const int spawnRate = 20; // prueba con 20 (más frecuente). Pon 5 para muchas.
  if(random(0, spawnRate) == 0){
    int cx = random(2, MATRIX_WIDTH - 2);
    int cy = random(2, MATRIX_HEIGHT - 2);
    CRGB color = CHSV(random8(), 255, 255);
    for(int dx = -2; dx <= 2; dx++){
      for(int dy = -2; dy <= 2; dy++){
        int x = cx + dx;
        int y = cy + dy;
        if(x >= 0 && x < MATRIX_WIDTH && y >= 0 && y < MATRIX_HEIGHT){
          float dist = sqrtf((float)(dx*dx + dy*dy));
          int bright = 255 - int(dist * 90.0f);
          if(bright > 0){
            // CORRECCIÓN: crear copia escalada y luego sumar
            CRGB scaled = color;
            scaled.nscale8((uint8_t)bright);
            fade[XY(x,y)] += scaled;
          }
        }
      }
    }
  }

  // copiar el buffer de fade a la salida y mostrar
  for(int i=0;i<NUM_LEDS;i++) leds[i] = fade[i];
  FastLED.show();
  delay(35);
}


void checkerboard(uint8_t t){
  for(uint8_t y=0;y<MATRIX_HEIGHT;y++){
    for(uint8_t x=0;x<MATRIX_WIDTH;x++){
      bool on = ((x/2 + y/2 + (t/10)) % 2) == 0;
      uint16_t idx = XY(x,y);
      if(on){
        leds[idx] = CHSV( (uint8_t)(160 + (x*3)), 200, 255 );
      } else {
        leds[idx] = CRGB::Black;
      }
    }
  }
  FastLED.show();
  delay(40);
}

// ----------------- Funciones de texto y scroll -----------------

// Limpiar matriz
void clearMatrix(){
  for(int i=0;i<NUM_LEDS;i++) leds[i] = CRGB::Black;
}

// Dibuja un solo pixel (si está en rango)
inline void drawPixelSafe(int x, int y, CRGB color){
  if(x < 0 || x >= MATRIX_WIDTH || y < 0 || y >= MATRIX_HEIGHT) return;
  leds[XY(x,y)] = color;
}

// Dibuja texto en una posición X (sin scroll), usando la fuente 5x7.
// x0 puede ser negativo para dibujar parcialmente.
void drawTextAt(int x0, const char* text, CRGB color){
  int x = x0;
  for(size_t i=0; text[i] != '\0'; ++i){
    char c = text[i];
    if(c >= 'a' && c <= 'z') c = c - 'a' + 'A'; // convertir a mayúsculas
    int idx = fontIndex(c);
    const uint8_t *glyph = font5x7[idx];
    // 5 columnas por caracter
    for(int col=0; col<5; ++col){
      uint8_t columnBits = glyph[col];
      for(int row=0; row<7; ++row){
        if(columnBits & (1<<row)){
          // centrar verticalmente (altura 7 => empezar en (16-7)/2 = 4)
          int y = row + (MATRIX_HEIGHT - 7)/2;
          drawPixelSafe(x + col, y, color);
        }
      }
    }
    x += 6; // 5 columnas + 1 columna de espacio
  }
}

// Crea un buffer de columnas para un texto y hace scroll de derecha a izquierda.
// speed = delay en ms por paso; color = CHSV/CRGB mezcla.
void scrollMessage(const char* text, uint8_t speed, CHSV colorHSV){
  // Construir buffer dinámico de columnas (vector simple con new/delete)
  // ancho_total = (len * 5) + (len * 1)  => len*6
  int len = strlen(text);
  int totalCols = len * 6;
  uint8_t *cols = (uint8_t*)malloc(totalCols);
  if(!cols) return; // si falla la memoria, salir graciosamente
  int colIdx = 0;
  for(int i=0;i<len;i++){
    char c = text[i];
    if(c >= 'a' && c <= 'z') c = c - 'a' + 'A';
    int fi = fontIndex(c);
    const uint8_t *g = font5x7[fi];
    for(int ccol=0; ccol<5; ++ccol){
      cols[colIdx++] = g[ccol];
    }
    cols[colIdx++] = 0x00; // columna de espacio entre caracteres
  }

  // Scroll: desde offset 0 (todo a derecha) hasta totalCols + MATRIX_WIDTH para pasar fuera.
  int scrollRange = totalCols + MATRIX_WIDTH;
  for(int off = 0; off < scrollRange; ++off){
    clearMatrix();
    // para cada columna visible en la matriz (x de 0..MATRIX_WIDTH-1)
    for(int x=0; x < MATRIX_WIDTH; ++x){
      int sourceCol = off + x - MATRIX_WIDTH; // cuando sourceCol < 0 => vacío
      if(sourceCol >= 0 && sourceCol < totalCols){
        uint8_t columnBits = cols[sourceCol];
        for(int row=0; row<7; ++row){
          if(columnBits & (1<<row)){
            int y = row + (MATRIX_HEIGHT - 7)/2;
            drawPixelSafe(x, y, colorHSV);
          }
        }
      }
    }
    FastLED.show();
    delay(speed);
  }

  free(cols);
}

// Muestra "HOLA" centrado (si cabe) durante duration ms
void showHola(unsigned long duration = 2000){
  const char *msg = "HOLA";
  // calcular ancho en columnas
  int len = strlen(msg);
  int width = len * 6 - 1; // última columna de espacio opcional - se resta 1
  int x0 = (MATRIX_WIDTH - width) / 2;
  if(x0 < 0) x0 = 0;
  clearMatrix();
  drawTextAt(x0, msg, CHSV(160, 200, 255));
  FastLED.show();
  delay(duration);
}

// ----------------- Interrupción de botón (secuencial de modos) -----------------
void IRAM_ATTR handleButton(){
  unsigned long now = millis();
  if(now - lastButtonMillis < debounce) return;
  lastButtonMillis = now;
  mode = (mode + 1) % MODES;
}

// ----------------- Setup / Loop -----------------
void setup(){
  Serial.begin(115200);
  delay(100);
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS).setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(BRIGHTNESS);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(BUTTON_PIN), handleButton, FALLING);
  randomSeed(analogRead(36));
  clearMatrix();
  FastLED.show();
}

void loop(){
  // detectar cambio de modo para reiniciar estado
  if(prevMode != mode){
    prevMode = mode;
    showHolaDone = false;
  }

  switch(mode){
    case 0:
      rainbowChase(20);
      break;
    case 1:
      plasma(1);
      break;
    case 2:
      fireworks();
      break;
    case 3:
      checkerboard(millis()/50);
      break;
    case 4:
      // scrollMessage hace un ciclo completo (entra/sale). Ejecutamos continuamente.
      scrollMessage("UPS CUENCA", 60, CHSV(0, 0, 255));
      break;
    default:
      mode = 0;
  }
}
