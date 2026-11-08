#!/usr/bin/env python3
"""Agrega el permiso de CÁMARA al AndroidManifest.xml que genera Capacitor (idempotente)."""
import sys
from pathlib import Path

ruta = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
if not ruta.exists():
    sys.exit(f"No existe {ruta}. Corre primero: npx cap add android")

xml = ruta.read_text(encoding="utf-8")
bloque = (
    '    <uses-permission android:name="android.permission.CAMERA" />\n'
    '    <uses-feature android:name="android.hardware.camera" android:required="false" />\n'
    '    <uses-feature android:name="android.hardware.camera.front" android:required="false" />\n'
)

if "android.permission.CAMERA" in xml:
    print("El permiso de cámara ya estaba en el manifiesto.")
    sys.exit(0)

marca = "</manifest>"
if xml.count(marca) != 1:
    sys.exit("El manifiesto no tiene el formato esperado (no se encontró un único </manifest>).")

xml = xml.replace(marca, "\n" + bloque + marca)
ruta.write_text(xml, encoding="utf-8")
print("Permiso de cámara agregado a", ruta)
