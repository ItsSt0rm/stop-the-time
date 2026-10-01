"""Genera los ic_launcher.png (Android 7, sin íconos adaptativos) del logo "anillo y punto".

Mismas proporciones que res/drawable/ic_launcher_foreground.xml, sobre un círculo con el fondo
de la app. Biblioteca estándar (PNG con zlib) y antialiasing por supermuestreo: determinista.

Uso:  python3 scripts/generate_launcher_png.py
"""

import struct
import zlib
from pathlib import Path

RES = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "res"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

BG = (0x0A, 0x0B, 0x0D)
FG = (0xA7, 0xAD, 0xB4)
SS = 4  # supermuestreo por eje

# Proporciones relativas al lado (sacadas del lienzo adaptativo: visible 72 de 108 dp).
BG_R = 0.48
RING_R = 20.5 / 72 * 1.0
RING_W = 2.6 / 72
DOT_R = 3.8 / 72


def pixel(size: int, x: int, y: int) -> tuple:
    acc = [0.0, 0.0, 0.0, 0.0]
    for sy in range(SS):
        for sx in range(SS):
            u = (x + (sx + 0.5) / SS) / size - 0.5
            v = (y + (sy + 0.5) / SS) / size - 0.5
            d = (u * u + v * v) ** 0.5
            if d > BG_R:
                continue
            on_fg = abs(d - RING_R) <= RING_W / 2 or d <= DOT_R
            c = FG if on_fg else BG
            acc[0] += c[0]
            acc[1] += c[1]
            acc[2] += c[2]
            acc[3] += 255
    n = SS * SS
    a = acc[3] / n
    if a == 0:
        return (0, 0, 0, 0)
    # Color no premultiplicado: promedio de las submuestras cubiertas.
    cov = acc[3] / 255
    return (round(acc[0] / cov), round(acc[1] / cov), round(acc[2] / cov), round(a))


def png(size: int) -> bytes:
    rows = b"".join(
        b"\x00" + b"".join(bytes(pixel(size, x, y)) for x in range(size)) for y in range(size)
    )

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    for density, size in SIZES.items():
        out = RES / f"mipmap-{density}" / "ic_launcher.png"
        out.write_bytes(png(size))
        print(f"OK: {out.relative_to(RES)} {size}x{size}")


if __name__ == "__main__":
    main()
