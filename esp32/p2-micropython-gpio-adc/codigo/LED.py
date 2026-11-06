# blink_pin5.py
# MicroPython para ESP32 WROOM-32
# Conecta un LED (con resistencia) al pin GPIO5 (GND compartido)

import machine
import time

print("Prueba ESP32 - parpadeo en GPIO5")

led = machine.Pin(5, machine.Pin.OUT)

while True:
    led.value(not led.value())  # toggle
    time.sleep(1)