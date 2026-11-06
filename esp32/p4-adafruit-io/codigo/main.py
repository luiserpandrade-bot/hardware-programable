# main.py - ESP32 MicroPython (Adafruit IO publish + subscribe)
# Requiere: umqtt.simple o umqtt.robust (subir a la placa o instalar via upip)

import network
import time
import sys
from machine import Pin, ADC

# Intentamos usar umqtt.robust si está disponible (mejor para reconexión)
try:
    from umqtt.robust import MQTTClient
except Exception:
    from umqtt.simple import MQTTClient

# --------- CONFIGURA AQUI ----------
SSID = "TU_RED_WIFI"
PASSWORD = "TU_CLAVE_WIFI"

ADAFRUIT_USERNAME = "TU_USUARIO"     # tu usuario Adafruit IO
ADAFRUIT_IO_KEY = "TU_AIO_KEY"
ADAFRUIT_IO_SERVER = "io.adafruit.com"
ADAFRUIT_IO_PORT = 1883

FEED_LED = "esp32.pulsante"
FEED_POT = "esp32.potenciometro"
# -----------------------------------

# Pines ESP32: ajusta si tu placa usa otro pin LED o ADC
LED_PIN = 2      # muchas placas ESP32 tienen LED en GPIO2; cámbialo si tu board usa otro
POT_PIN = 34     # pin ADC (GPIO34 es input-only, ADC1_CH6)

led = Pin(LED_PIN, Pin.OUT)

# Configura ADC (ESP32)
adc = ADC(Pin(POT_PIN))
try:
    # ajustes comunes para ESP32: 11dB atten -> rango ~0-3.6V, 12bit width -> 0-4095
    adc.atten(ADC.ATTN_11DB)
    adc.width(ADC.WIDTH_12BIT)
except Exception:
    # algunas builds usan read_u16 directamente sin atten/width
    pass

# Función para leer ADC de forma portable (int 0..65535)
def read_adc_u16(adc_obj):
    # intenta read_u16 si está disponible (RP Pico style), si no usa read() y lo escala
    try:
        v = adc_obj.read_u16()
        return int(v)
    except Exception:
        # si read() devuelve 0..4095, lo escalamos a 0..65535
        try:
            v = adc_obj.read()
            return int((v * 65535) // 4095)
        except Exception:
            return 0

# Construye topics en string y codifica cuando hace falta
def topic_for(feedname):
    return "{}/feeds/{}".format(ADAFRUIT_USERNAME, feedname)

# Callback de mensajes recibidos (subscribe)
def mqtt_callback(topic, msg):
    # topic y msg vienen como bytes
    try:
        t = topic.decode()
        m = msg.decode()
    except Exception:
        t = str(topic)
        m = str(msg)
    print("MSG IN -> topic:", t, " msg:", m)
    # si el feed del LED recibió un '0' o '1'
    if FEED_LED in t:
        if m.strip() == '0':
            led.value(0)
        else:
            led.value(1)
        print("LED set to", led.value())

# Conexión WiFi
def wifi_connect():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if not wlan.isconnected():
        print("Conectando a WiFi...")
        wlan.connect(SSID, PASSWORD)
        # esperar hasta conectarse (mejor poner timeout en producción)
        timeout = 20
        start = time.time()
        while not wlan.isconnected():
            if time.time() - start > timeout:
                raise RuntimeError("No se pudo conectar a la WiFi (timeout)")
            time.sleep(0.5)
    print("Conectado. IP:", wlan.ifconfig()[0])

# Crea y conecta cliente MQTT
def mqtt_connect_and_subscribe():
    client_id = "esp32-" + str(int(time.time()))
    client = MQTTClient(client_id=client_id,
                        server=ADAFRUIT_IO_SERVER,
                        port=ADAFRUIT_IO_PORT,
                        user=ADAFRUIT_USERNAME,
                        password=ADAFRUIT_IO_KEY,
                        ssl=False)
    client.set_callback(mqtt_callback)
    print("Conectando a Adafruit IO MQTT...")
    client.connect()
    sub_topic = topic_for(FEED_LED)
    client.subscribe(sub_topic.encode())
    print("Subscribed to", sub_topic)
    return client

def main():
    try:
        wifi_connect()
    except Exception as e:
        print("WiFi error:", e)
        sys.exit()

    try:
        client = mqtt_connect_and_subscribe()
    except Exception as e:
        print("MQTT connect error:", e)
        sys.exit()

    pot_topic = topic_for(FEED_POT).encode()
    print("Loop principal iniciado. Publicando en:", pot_topic)

    last_publish = 0
    publish_interval = 2.0  # segundos

    try:
        while True:
            # recibe mensajes pendientes (no bloqueante)
            try:
                client.check_msg()   # non-blocking, llama mqtt_callback para nuevos mensajes
            except OSError as e:
                print("Error MQTT (check_msg):", e)
                # intentar reconectar
                try:
                    client.disconnect()
                except Exception:
                    pass
                time.sleep(2)
                client = mqtt_connect_and_subscribe()

            # publicar valor del potenciómetro cada publish_interval segundos
            now = time.time()
            if now - last_publish >= publish_interval:
                v = read_adc_u16(adc)
                payload = str(v).encode()
                try:
                    client.publish(pot_topic, payload)
                    print("Publicado ->", pot_topic.decode(), payload.decode())
                except OSError as e:
                    print("Publish error:", e)
                    # intentar reconectar
                    try:
                        client.disconnect()
                    except Exception:
                        pass
                    time.sleep(2)
                    client = mqtt_connect_and_subscribe()
                last_publish = now

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("Detenido por usuario")
    finally:
        try:
            client.disconnect()
        except Exception:
            pass

if __name__ == "__main__":
    main()
