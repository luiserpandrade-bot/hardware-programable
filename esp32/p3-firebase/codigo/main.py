# -*- coding: utf-8 -*-
# main.py — ESP32 (MicroPython)
# Guarda este archivo directamente en la placa usando Thonny.

import network
import urequests as requests
import time
import gc

# =======================
# CONFIG (credenciales)
# =======================
WIFI_SSID = 'TU_RED_WIFI'
WIFI_PASSWORD = 'TU_CLAVE_WIFI'

FIREBASE_URL = 'https://TU-PROYECTO-default-rtdb.firebaseio.com/'
FIREBASE_API_KEY = 'TU_API_KEY_DE_FIREBASE'
FIREBASE_EMAIL = 'usuario@ejemplo.com'
FIREBASE_PASSWORD = 'TU_CLAVE_FIREBASE'

# Intervalo de lectura en segundos (ajusta aquí)
POLL_INTERVAL = 3  # lectura cada 3 segundos

# =======================
# Variables internas
# =======================
id_token = None
wlan = None

# =======================
# Funciones
# =======================
def connect_wifi(timeout=15):
    """Conecta el ESP32 a la red WiFi. Lanza RuntimeError si falla."""
    global wlan
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if wlan.isconnected():
        print("✅ WiFi ya conectado. IP:", wlan.ifconfig()[0])
        return

    print("🔌 Activando interfaz WiFi...")
    wlan.connect(WIFI_SSID, WIFI_PASSWORD)
    start = time.time()
    while not wlan.isconnected():
        if time.time() - start > timeout:
            raise RuntimeError("⛔ Timeout: no se pudo conectar a WiFi")
        print(".", end="")
        time.sleep(1)
    print("\n✅ WiFi conectado. IP:", wlan.ifconfig()[0])

def firebase_auth():
    """Autentica contra Firebase Auth REST y actualiza id_token global."""
    global id_token
    auth_url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={}".format(FIREBASE_API_KEY)
    auth_data = {
        "email": FIREBASE_EMAIL,
        "password": FIREBASE_PASSWORD,
        "returnSecureToken": True
    }
    try:
        print("🔐 Autenticando en Firebase...")
        resp = requests.post(auth_url, json=auth_data)
        if resp.status_code == 200:
            j = resp.json()
            id_token = j.get("idToken")
            if not id_token:
                print("❌ No se recibió idToken en la respuesta.")
                return False
            print("🔑 Autenticación exitosa.")
            return True
        else:
            print("❌ Error auth (HTTP {}): {}".format(resp.status_code, resp.text))
            return False
    except Exception as e:
        print("❌ Excepción durante auth:", e)
        return False
    finally:
        try:
            resp.close()
        except:
            pass
        gc.collect()

def read_firebase_data():
    """Lee el nodo /random.json con el idToken actual."""
    if not id_token:
        print("⚠️ No hay id_token — autentícate primero.")
        return None
    url = "{}random.json?auth={}".format(FIREBASE_URL, id_token)
    try:
        resp = requests.get(url)
        if resp.status_code == 200:
            data = resp.json() or {}
            # Impresión formateada
            print("\n" + "═"*40)
            print("📊 DATOS DE FIREBASE (nodo /random)")
            print("═"*40)
            print("🔢 data     :", data.get("data", "N/D"))
            print("🌡 temperatura:", "{}°C".format(data.get("temperatura", "N/D")))
            print("═"*40)
            return data
        else:
            print("❌ Error lectura (HTTP {}): {}".format(resp.status_code, resp.text))
            # Si token expiró, Firebase devuelve 401 o info similar -> retornar None para re-auth
            return None
    except Exception as e:
        print("❌ Excepción en lectura:", e)
        return None
    finally:
        try:
            resp.close()
        except:
            pass
        gc.collect()

def main():
    global id_token
    try:
        connect_wifi()
    except Exception as e:
        print("⚠️ No se pudo iniciar WiFi:", e)
        return

    # Intentos de autenticación (reintentar 2 veces)
    for attempt in range(3):
        if firebase_auth():
            break
        print("🔁 Reintentando auth... ({}/{})".format(attempt+1, 3))
        time.sleep(2)
    else:
        print("⛔ No se pudo autenticar en Firebase — abortando.")
        return

    print("\n🔄 Iniciando bucle de monitoreo (CTRL+C para detener)...")
    last_auth_time = time.time()
    AUTH_EXPIRY_SECONDS = 50 * 60  # reauth cada 50 min (ajustable)

    try:
        while True:
            data = read_firebase_data()
            if data is None:
                # Posible token expirado o error puntual: intentar re-autenticar una vez
                print("🔁 Intentando re-autenticación...")
                if not firebase_auth():
                    print("❌ Re-auth fallida. Esperando y reintentando más tarde.")
                    time.sleep(5)
                else:
                    print("✅ Re-auth exitosa.")
            # Reautenticar periódicamente para evitar tokens caducados
            if time.time() - last_auth_time > AUTH_EXPIRY_SECONDS:
                print("⏱ Reautenticando por tiempo transcurrido...")
                if firebase_auth():
                    last_auth_time = time.time()
            time.sleep(POLL_INTERVAL)
    except KeyboardInterrupt:
        print("\n🛑 Bucle detenido por usuario.")
    except Exception as e:
        print("‼️ Error inesperado en main loop:", e)
    finally:
        try:
            if wlan:
                wlan.disconnect()
                wlan.active(False)
        except:
            pass
        gc.collect()
        print("✅ Fin.")

# =======================
# Ejecutar
# =======================
if __name__ == "__main__":
    main()
