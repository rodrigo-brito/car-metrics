#!/usr/bin/env python3
"""Captura a tela do ESP32 pelo serial (comando 'S') e salva PNG.
Uso: python3 tools/shot.py [run|boot] [saida.png] [porta]
  run  = captura a tela atual   boot = reseta a placa e captura o splash"""
import serial, struct, sys, time, glob, subprocess
mode = sys.argv[1] if len(sys.argv) > 1 else 'run'
out = sys.argv[2] if len(sys.argv) > 2 else 'tela.png'
port = sys.argv[3] if len(sys.argv) > 3 else (glob.glob('/dev/cu.usbserial-*') + [None])[0]
s = serial.Serial(port, 115200, timeout=2)
if mode == 'boot':
    s.setDTR(False); s.setRTS(True); time.sleep(0.1); s.setRTS(False); time.sleep(0.4)
else:
    time.sleep(1.5); s.reset_input_buffer()
s.write(b'S')
hdr = b''; t0 = time.time()
while b'IMG 320 240' not in hdr and time.time() - t0 < 15: hdr += s.read(256)
if b'IMG 320 240' not in hdr: sys.exit("sem cabecalho")
data = hdr[hdr.index(b'IMG 320 240') + len(b'IMG 320 240\r\n'):]
need = 320 * 240 * 3; t0 = time.time()
while len(data) < need and time.time() - t0 < 60: data += s.read(need - len(data))
w, h = 320, 240; px = bytearray()
for y in range(h - 1, -1, -1):
    row = data[y * w * 3:(y + 1) * w * 3]
    for x in range(w): px += bytes((row[x*3+2], row[x*3+1], row[x*3]))   # BGR; leitura do painel vem com R/B trocados
bmp = out.rsplit('.', 1)[0] + '.bmp'
open(bmp, 'wb').write(b'BM' + struct.pack('<IHHI', 54 + len(px), 0, 0, 54) + struct.pack('<IiiHHIIiiII', 40, w, h, 1, 24, 0, len(px), 2835, 2835, 0, 0) + px)
subprocess.run(['sips', '-s', 'format', 'png', bmp, '--out', out], capture_output=True)
print("salvo", out)
