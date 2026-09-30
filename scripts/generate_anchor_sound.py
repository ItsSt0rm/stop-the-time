"""Genera assets/audio/anchor.wav: el sonido del ancla de "Para el tiempo".

Tono suave tipo cuenco: una fundamental grave con parciales inarmónicos que decaen rápido,
un leve batido (dos fundamentales separadas <1 Hz) y ataque suave. Solo biblioteca estándar
y sin aleatoriedad: el resultado es idéntico en cada ejecución (reproducible y verificable
por hash). Sin licencias de terceros.

Uso:  python3 scripts/generate_anchor_sound.py
"""

import hashlib
import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
DURATION_S = 4.0
PEAK = 0.35  # ~ -9 dBFS: presente pero no invasivo
F0 = 196.0  # Sol3

# (relación con F0, amplitud relativa, constante de decaimiento en s)
PARTIALS = [
    (1.0, 1.0, 1.30),
    (1.0 + 0.7 / F0, 0.35, 1.30),  # batido lento (~0.7 Hz) con la fundamental
    (2.76, 0.30, 0.70),
    (5.40, 0.10, 0.35),
    (8.93, 0.04, 0.20),
]
ATTACK_S = 0.02
RELEASE_S = 0.30

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "anchor.wav"


def envelope(t: float) -> float:
    attack = 0.5 - 0.5 * math.cos(math.pi * min(t / ATTACK_S, 1.0))
    to_end = DURATION_S - t
    release = 0.5 - 0.5 * math.cos(math.pi * min(to_end / RELEASE_S, 1.0))
    return attack * release


def main() -> None:
    n = int(SAMPLE_RATE * DURATION_S)
    raw = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = sum(
            amp * math.exp(-t / tau) * math.sin(2 * math.pi * F0 * ratio * t)
            for ratio, amp, tau in PARTIALS
        )
        raw.append(s * envelope(t))

    scale = PEAK / max(abs(x) for x in raw)
    frames = b"".join(struct.pack("<h", round(x * scale * 32767)) for x in raw)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames)

    digest = hashlib.sha256(OUT.read_bytes()).hexdigest()
    print(f"OK: {OUT.name}  {OUT.stat().st_size} bytes  sha256={digest}")


if __name__ == "__main__":
    main()
