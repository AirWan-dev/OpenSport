"""Simule une course sur l'émulateur Android : une position GPS par seconde.

Usage : python3 tool/simulate_run.py [durée_en_secondes]
Lancer l'émulateur et l'app, démarrer l'enregistrement, puis ce script.
"""
import math, os, subprocess, sys, time

ADB = os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')
lat0, lng0 = 48.8625, 2.2510
R = 6371000.0
seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 150
speed = 3.3  # m/s, environ 5'03"/km
radius = 700.0
for t in range(seconds):
    theta = speed * t / radius
    r = radius * (1 + 0.15 * math.sin(3 * theta))
    north, east = r * math.cos(theta) - radius, r * math.sin(theta)
    lat = lat0 + math.degrees(north / R)
    lng = lng0 + math.degrees(east / (R * math.cos(math.radians(lat0))))
    alt = 35 + 8 * math.sin(2 * theta)
    subprocess.run([ADB, 'emu', 'geo', 'fix', f'{lng:.7f}', f'{lat:.7f}', f'{alt:.1f}'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
