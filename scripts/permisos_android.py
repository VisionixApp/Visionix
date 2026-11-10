#!/usr/bin/env python3
"""Ajusta el AndroidManifest.xml que genera Capacitor (idempotente: se puede correr varias veces):
  1. Agrega el permiso de CÁMARA.
  2. Permite conexiones http:// (sin cifrar) desde el código nativo, para leer la foto de una cámara IP de la red local
     (p. ej. http://192.168.1.110/snapshot.jpg). La página de la app sigue cargándose por https y no puede abrir http por su cuenta.
"""
import re
import sys
from pathlib import Path

ruta = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
if not ruta.exists():
    sys.exit(f"No existe {ruta}. Corre primero: npx cap add android")

xml = ruta.read_text(encoding="utf-8")
cambios = []

# 1) permiso de cámara
bloque = (
    '    <uses-permission android:name="android.permission.CAMERA" />\n'
    '    <uses-feature android:name="android.hardware.camera" android:required="false" />\n'
    '    <uses-feature android:name="android.hardware.camera.front" android:required="false" />\n'
)
if "android.permission.CAMERA" in xml:
    print("El permiso de cámara ya estaba en el manifiesto.")
else:
    marca = "</manifest>"
    if xml.count(marca) != 1:
        sys.exit("El manifiesto no tiene el formato esperado (no se encontró un único </manifest>).")
    xml = xml.replace(marca, "\n" + bloque + marca)
    cambios.append("permiso de cámara")

# 2) tráfico http:// hacia cámaras de la red local
apertura = re.search(r"<application\b[^>]*>", xml, flags=re.S)
if not apertura:
    sys.exit("El manifiesto no tiene el formato esperado (no se encontró la etiqueta <application>).")
if "usesCleartextTraffic" in apertura.group(0):
    if re.search(r'android:usesCleartextTraffic\s*=\s*"true"', apertura.group(0)):
        print("El tráfico http:// ya estaba permitido en el manifiesto.")
    else:
        nueva = re.sub(r'android:usesCleartextTraffic\s*=\s*"[^"]*"', 'android:usesCleartextTraffic="true"', apertura.group(0))
        xml = xml[:apertura.start()] + nueva + xml[apertura.end():]
        cambios.append("tráfico http:// (corregido a true)")
else:
    nueva = apertura.group(0).replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
    xml = xml[:apertura.start()] + nueva + xml[apertura.end():]
    cambios.append("tráfico http:// para cámaras IP")

if cambios:
    ruta.write_text(xml, encoding="utf-8")
    print("Manifiesto actualizado (" + ", ".join(cambios) + "):", ruta)
