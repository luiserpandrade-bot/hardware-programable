// Prueba simple para motor con ChipKIT Max32 + Motor Shield
// PWM -> pin 3 (RD0 / OC1)
// DIR -> pin 4 (RF1)
// BTN -> pin 7 (a GND, use INPUT_PULLUP)  <-- único botón

const int PWM_PIN   = 3;   // RD0 / OC1
const int DIR_PIN   = 4;   // RF1
const int BTN       = 78;   // botón (a GND)

int duty = 0;                 // 0..255 (valor inicial)
const int STEP = 25;          // incremento por pulsación
const int DUTY_MIN = 0;
const int DUTY_MAX = 255;

int lastButtonState = HIGH;   // estado anterior del botón (INPUT_PULLUP: idle = HIGH)

void setup() {
  pinMode(PWM_PIN, OUTPUT);
  pinMode(DIR_PIN, OUTPUT);

  pinMode(BTN, INPUT_PULLUP);

  // Estado inicial
  digitalWrite(DIR_PIN, LOW);
  analogWrite(PWM_PIN, duty);
}

void loop() {
  int current = digitalRead(BTN);

  // Detección de flanco: HIGH -> LOW significa "pulsado"
  if (lastButtonState == HIGH && current == LOW) {
    duty += STEP;
    if (duty > DUTY_MAX) duty = DUTY_MIN; // si supera el máximo, reinicia
    analogWrite(PWM_PIN, duty);
  }

  lastButtonState = current;

  delay(100); // pequeño retardo para aliviar CPU (no es debounce)
}

