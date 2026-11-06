# adc_pot_esp32.py
# Lectura de potenciómetro en GPIO34 (ADC1_CH6)
# Nota: en ESP32 muchos pines ADC son de solo entrada (p. ej. 34,35,36,39).
# Ajustamos atenuación para máximo rango.

from machine import Pin, ADC
import time

# Pin recomendado: 32, 33, 34, 35, 36(GPIO36) o 39. Aquí uso 34.
pot = ADC(Pin(34))               # ADC en GPIO34
pot.atten(ADC.ATTN_11DB)         # rango ~0-3.3V
pot.width(ADC.WIDTH_12BIT)      # resolución 0-4095

while True:
    raw = pot.read()            # 0 - 4095
    volts = raw / 4095 * 3.3
    print("ADC raw:", raw, "-> {:.2f} V".format(volts))
    time.sleep(0.5)
