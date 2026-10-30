#!/usr/bin/env python3
"""Valida um adaptador ELM327 BLE (serviço FFF0) a partir do Mac: lista características,
roda a inicialização e consulta PIDs básicos. Uso: python3 tools/ble_probe.py [NOME]
Requer: pip install bleak"""
import asyncio, sys
from bleak import BleakClient, BleakScanner
NAME = sys.argv[1] if len(sys.argv) > 1 else "KONNWEI"
async def main():
    dev = await BleakScanner.find_device_by_name(NAME, timeout=15)
    if not dev: print("nao achou", NAME); return
    async with BleakClient(dev, timeout=20) as c:
        print("conectado, mtu", c.mtu_size)
        rx = tx = None
        for svc in c.services:
            print("svc", svc.uuid)
            for ch in svc.characteristics:
                print("   ch", ch.uuid, ch.properties)
                u = ch.uuid.lower()
                if u.startswith("0000fff1") and "notify" in ch.properties: rx = ch
                if u.startswith("0000fff2") and ("write" in ch.properties or "write-without-response" in ch.properties): tx = ch
        buf = bytearray()
        await c.start_notify(rx, lambda _, d: buf.extend(d))
        async def cmd(s, wait=2.0):
            buf.clear()
            await c.write_gatt_char(tx, (s + "\r").encode(), response=False)
            t = 0
            while t < wait and b'>' not in buf: await asyncio.sleep(0.1); t += 0.1
            print(f"{s:8} -> {buf.decode(errors='replace').replace(chr(13), ' | ').strip()}")
        for s in ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0", "ATI", "ATRV", "0100", "0120", "ATDPN",
                  "010C", "010D", "0105", "0110", "012F", "0104", "010B", "010F", "0111"]:
            await cmd(s, 8 if s in ("ATZ", "0100") else 2)
asyncio.run(main())
