"""Genera el sonido del ancla de "Para el tiempo".

Síntesis aditiva con biblioteca estándar y sin aleatoriedad: cada preset produce siempre el
mismo archivo (reproducible y verificable por hash). Sin licencias de terceros.

Uso:
  python3 scripts/generate_anchor_sound.py                  # preset de la app -> assets/audio/anchor.wav
  python3 scripts/generate_anchor_sound.py --variants DIR   # todos los presets en DIR, para comparar
"""

import argparse
import hashlib
import math
import struct
import wave
from dataclasses import dataclass
from pathlib import Path

SAMPLE_RATE = 44_100
PEAK = 0.35  # ~ -9 dBFS: presente pero no invasivo


@dataclass(frozen=True)
class Preset:
    description: str
    f0: float
    duration_s: float
    # (relación con f0, amplitud relativa, constante de decaimiento en s)
    partials: list
    attack_s: float
    release_s: float


def _bowl(f0: float) -> list:
    return [
        (1.0, 1.0, 1.30),
        (1.0 + 0.7 / f0, 0.35, 1.30),  # batido lento (~0.7 Hz) con la fundamental
        (2.76, 0.30, 0.70),
        (5.40, 0.10, 0.35),
        (8.93, 0.04, 0.20),
    ]


PRESETS = {
    "campana": Preset("Cuenco/campana, Sol3", 196.0, 4.0, _bowl(196.0), 0.02, 0.30),
    "cuenco-grave": Preset(
        "Cuenco más grave y cálido, Do3, menos brillo",
        130.81,
        4.5,
        [
            (1.0, 1.0, 1.80),
            (1.0 + 0.5 / 130.81, 0.40, 1.80),
            (2.76, 0.15, 0.80),
            (5.40, 0.04, 0.35),
        ],
        0.03,
        0.40,
    ),
    "soplo": Preset(
        "Sin golpe: entra despacio y se desvanece (más 'aire' que campana)",
        174.61,
        4.0,
        [(1.0, 1.0, 3.0), (2.0, 0.20, 2.0), (1.0 + 0.4 / 174.61, 0.50, 3.0)],
        0.60,
        1.20,
    ),
    "madera": Preset(
        "Toque breve tipo marimba, discreto",
        261.63,
        1.6,
        [(1.0, 1.0, 0.45), (4.0, 0.25, 0.12), (10.0, 0.05, 0.05)],
        0.005,
        0.20,
    ),
}

# Elegido por la persona usuaria tras comparar variantes. Si cambia, actualizar el sha256 de
# test/anchor_asset_test.dart.
APP_PRESET = "soplo"
APP_OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "anchor.wav"


def render(p: Preset, out: Path) -> None:
    def envelope(t: float) -> float:
        attack = 0.5 - 0.5 * math.cos(math.pi * min(t / p.attack_s, 1.0))
        to_end = p.duration_s - t
        release = 0.5 - 0.5 * math.cos(math.pi * min(to_end / p.release_s, 1.0))
        return attack * release

    n = int(SAMPLE_RATE * p.duration_s)
    raw = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = sum(
            amp * math.exp(-t / tau) * math.sin(2 * math.pi * p.f0 * ratio * t)
            for ratio, amp, tau in p.partials
        )
        raw.append(s * envelope(t))

    scale = PEAK / max(abs(x) for x in raw)
    frames = b"".join(struct.pack("<h", round(x * scale * 32767)) for x in raw)

    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames)

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"OK: {out.name}  {out.stat().st_size} bytes  sha256={digest}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", type=Path, help="genera todos los presets en este directorio")
    args = parser.parse_args()

    if args.variants:
        for name, preset in PRESETS.items():
            print(f"- {name}: {preset.description}")
            render(preset, args.variants / f"{name}.wav")
    else:
        render(PRESETS[APP_PRESET], APP_OUT)


if __name__ == "__main__":
    main()
