# led_button_gpio16.py
# Pulsador en GPIO16, LED en GPIO5
# El pulsador debe conectar a GND cuando se presiona (uso de PULL_UP interno).

from machine import Pin
import time

led = Pin(5, Pin.OUT)
button = Pin(16, Pin.IN, Pin.PULL_UP)  # pulsador a GND -> activo LOW

DEBOUNCE_MS = 50

last_state = button.value()
last_time = time.ticks_ms()

while True:
    state = button.value()
    if state != last_state:
        # primer filtrado por rebote
        t = time.ticks_ms()
        if time.ticks_diff(t, last_time) > DEBOUNCE_MS:
            last_state = state
            last_time = t
            if state == 0:  # presionado (LOW)
                led.on()
            else:
                led.off()
    time.sleep_ms(10)
