#!/usr/bin/env python3
"""SFX originales: python tools/audio/generar_sfx.py [paso_1 voltereta ...].

Sin argumentos genera todo; un nombre de familia selecciona sus variantes.
Para generar solo el segundo lote: python tools/audio/generar_sfx.py lote_2.
Solo usa la biblioteca estándar y nunca descarga ni lee samples externos.
"""

import math
from pathlib import Path
import random
import struct
import sys
import wave


# Parámetros independientes por archivo. pitch multiplica todas las frecuencias;
# duration estira la composición; peak_db controla volumen; brightness controla
# el filtro final (Hz). seed cambia textura y distribución de los fragmentos.
SONIDOS = {
    "paso_1": dict(family="paso", duration=0.090, pitch=0.96, peak_db=-9, brightness=2400, seed=101, limits=(0.07, 0.12)),
    "paso_2": dict(family="paso", duration=0.105, pitch=1.04, peak_db=-9, brightness=2150, seed=102, limits=(0.07, 0.12)),
    "paso_3": dict(family="paso", duration=0.082, pitch=1.07, peak_db=-9, brightness=2550, seed=103, limits=(0.07, 0.12)),
    "paso_4": dict(family="paso", duration=0.115, pitch=0.93, peak_db=-9, brightness=2250, seed=104, limits=(0.07, 0.12)),
    "espada_1": dict(family="espada", retro=True, duration=0.240, pitch=0.97, peak_db=-6, brightness=4800, seed=201, limits=(0.20, 0.30)),
    "espada_2": dict(family="espada", retro=True, duration=0.270, pitch=1.05, peak_db=-6, brightness=4500, seed=202, limits=(0.20, 0.30)),
    "vasija_romper_1": dict(family="vasija_romper", duration=0.590, pitch=0.96, peak_db=-3, brightness=4700, seed=301, limits=(0.50, 0.70)),
    "vasija_romper_2": dict(family="vasija_romper", duration=0.650, pitch=1.04, peak_db=-3, brightness=4400, seed=302, limits=(0.50, 0.70)),
    "piedra_caer_1": dict(family="piedra_caer", duration=0.280, pitch=0.95, peak_db=-3, brightness=2300, seed=401, limits=(0.20, 0.35)),
    "piedra_caer_2": dict(family="piedra_caer", duration=0.320, pitch=1.06, peak_db=-3, brightness=2600, seed=402, limits=(0.20, 0.35)),
    "golpe_enemigo_1": dict(family="golpe_enemigo", retro=True, duration=0.185, pitch=0.96, peak_db=-3, brightness=3600, seed=501, limits=(0.15, 0.25)),
    "golpe_enemigo_2": dict(family="golpe_enemigo", retro=True, duration=0.215, pitch=1.05, peak_db=-3, brightness=3300, seed=502, limits=(0.15, 0.25)),
    "leonidas_caer": dict(family="leonidas_caer", retro=True, duration=1.020, pitch=1.00, peak_db=-3, brightness=3100, seed=601, limits=(0.80, 1.20)),
    "barco_golpe_1": dict(family="barco_golpe", duration=0.480, pitch=0.96, peak_db=-3, brightness=3900, seed=701, limits=(0.40, 0.60)),
    "barco_golpe_2": dict(family="barco_golpe", retro=True, duration=0.550, pitch=1.04, peak_db=-3, brightness=3600, seed=702, limits=(0.40, 0.60)),
    "leonidas_danio_1": dict(family="leonidas_danio", retro=True, duration=0.240, pitch=0.97, peak_db=-3, brightness=3800, seed=801, limits=(0.20, 0.30)),
    "leonidas_danio_2": dict(family="leonidas_danio", retro=True, duration=0.280, pitch=1.05, peak_db=-3, brightness=3500, seed=802, limits=(0.20, 0.30)),
    "voltereta_1": dict(family="voltereta", duration=0.390, pitch=0.96, peak_db=-3, brightness=3600, seed=901, limits=(0.35, 0.45)),
    "voltereta_2": dict(family="voltereta", duration=0.430, pitch=1.04, peak_db=-3, brightness=3300, seed=902, limits=(0.35, 0.45)),
    # LOTE 2. notes controla las frecuencias base de cada motivo (Hz).
    "moneda_recoger_1": dict(batch=2, family="moneda_recoger", duration=0.190, pitch=0.98, peak_db=-3, brightness=4100, seed=1001, notes=(1300, 1900), limits=(0.15, 0.25)),
    "moneda_recoger_2": dict(batch=2, family="moneda_recoger", duration=0.215, pitch=1.04, peak_db=-3, brightness=3850, seed=1002, notes=(1300, 1900), limits=(0.15, 0.25)),
    "objeto_recoger": dict(batch=2, family="objeto_recoger", duration=0.300, pitch=1.0, peak_db=-3, brightness=2900, seed=1101, notes=(659.255, 830.609, 987.767), limits=(0.30, 0.30)),
    "dialogo_avanzar_1": dict(batch=2, family="dialogo_avanzar", duration=0.045, pitch=0.96, peak_db=-12, brightness=2000, seed=1201, notes=(720,), limits=(0.04, 0.06)),
    "dialogo_avanzar_2": dict(batch=2, family="dialogo_avanzar", duration=0.050, pitch=1.02, peak_db=-12, brightness=1850, seed=1202, notes=(720,), limits=(0.04, 0.06)),
    "dialogo_avanzar_3": dict(batch=2, family="dialogo_avanzar", duration=0.055, pitch=1.06, peak_db=-12, brightness=2150, seed=1203, notes=(720,), limits=(0.04, 0.06)),
    "dialogo_abrir": dict(batch=2, family="dialogo_abrir", duration=0.100, pitch=1.0, peak_db=-10, brightness=2300, seed=1301, notes=(540, 680), limits=(0.10, 0.10)),
    "dialogo_letra": dict(batch=2, family="dialogo_letra", duration=0.025, pitch=1.0, peak_db=-15, brightness=1800, seed=1401, notes=(600,), limits=(0.02, 0.03)),
    "comer": dict(batch=2, family="comer", duration=0.500, pitch=1.0, peak_db=-3, brightness=3100, seed=1501, notes=(310, 190), limits=(0.50, 0.50)),
    "curar": dict(batch=2, family="curar", duration=0.400, pitch=1.0, peak_db=-3, brightness=2800, seed=1601, notes=(440, 554.365, 659.255, 880), limits=(0.40, 0.40)),
    "menu_mover": dict(batch=2, family="menu_mover", duration=0.050, pitch=1.0, peak_db=-9, brightness=2600, seed=1701, notes=(1250,), limits=(0.05, 0.05)),
    "menu_aceptar": dict(batch=2, family="menu_aceptar", duration=0.120, pitch=1.0, peak_db=-9, brightness=2900, seed=1801, notes=(784, 1046.502), limits=(0.12, 0.12)),
    "menu_volver": dict(batch=2, family="menu_volver", duration=0.100, pitch=1.0, peak_db=-9, brightness=2300, seed=1901, notes=(740, 494), limits=(0.10, 0.10)),
}

RATE = 44100
OUTPUT = Path(__file__).resolve().parents[2] / "assets/audio/sfx"
TAU = 2 * math.pi


def lowpass(signal, cutoff):
    """Butterworth de segundo orden; dos pasadas dan una caída suave de 24 dB/oct."""
    w = TAU * cutoff / RATE
    c, s = math.cos(w), math.sin(w)
    alpha = s / math.sqrt(2)
    a0 = 1 + alpha
    b0, b1, b2 = (1 - c) / (2 * a0), (1 - c) / a0, (1 - c) / (2 * a0)
    a1, a2 = -2 * c / a0, (1 - alpha) / a0
    for _ in range(2):
        x1 = x2 = y1 = y2 = 0.0
        result = []
        for x in signal:
            y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            result.append(y)
            x2, x1, y2, y1 = x1, x, y1, y
        signal = result
    return signal


def synthesize(p):
    rng = random.Random(p["seed"])
    duration, pitch = p["duration"], p["pitch"]
    n = round(duration * RATE)
    signal = [0.0] * n

    def tone(start, length, f0, f1, gain, decay=5, harmonics=0.0):
        phase = 0.0
        count = max(2, round(length * RATE))
        offset = round(start * RATE)
        for j in range(min(count, n - offset)):
            u = j / (count - 1)
            phase += TAU * pitch * (f0 + (f1 - f0) * u) / RATE
            attack = min(1.0, j / (RATE * 0.0007))
            env = attack * math.exp(-decay * u) * (1 - u) ** 0.6
            signal[offset + j] += gain * env * (math.sin(phase) + harmonics * math.sin(phase * 2.37))

    def noise(start, length, f0, f1, gain, decay=5, swell=False, width=0.65):
        # Dos filtros de un polo en paralelo forman una banda de ruido móvil.
        lo = hi = 0.0
        count = max(2, round(length * RATE))
        offset = round(start * RATE)
        for j in range(min(count, n - offset)):
            u = j / (count - 1)
            center = pitch * (f0 + (f1 - f0) * math.sin(math.pi * u))
            al = 1 - math.exp(-TAU * center * width / RATE)
            ah = 1 - math.exp(-TAU * center / width / RATE)
            x = rng.uniform(-1, 1)
            lo += al * (x - lo)
            hi += ah * (x - hi)
            env = math.exp(-decay * u) * (1 - u)
            env *= min(1.0, j / (RATE * 0.0005))
            if swell:
                env *= 0.12 + 3.5 * math.sin(math.pi * u) ** 1.4
            signal[offset + j] += gain * env * (hi - lo)

    def arcade(start, length, f0, f1, gain, decay=5, pulse=False):
        # Oscilador aditivo sin aliasing: triángulo o pulso de consola clásica.
        # Barrido escalonado a 180 Hz, sin cuantizar la envolvente ni crear clics.
        phase = 0.0
        count = max(2, round(length * RATE))
        offset = round(start * RATE)
        for j in range(min(count, n - offset)):
            t = j / RATE
            u = j / (count - 1)
            step = min(1.0, math.floor(t * 180) / max(1, length * 180))
            freq = pitch * f0 * (f1 / f0) ** step
            phase += TAU * freq / RATE
            value = 0.0
            for h in (1, 3, 5, 7, 9):
                if h * freq < 5600:
                    weight = 1 / h if pulse else (-1) ** ((h - 1) // 2) / (h * h)
                    value += weight * math.sin(h * phase)
            env = min(1.0, t / 0.0007) * math.exp(-decay * u) * (1 - u) ** 0.6
            signal[offset + j] += gain * env * value

    def iron(start, length, fundamental, gain):
        # Modos inarmónicos de una hoja de hierro; cola corta, no campana larga.
        for ratio, level in ((1, 1), (1.47, 0.57), (2.09, 0.38), (2.73, 0.19)):
            freq = fundamental * ratio
            tone(start, length / ratio ** 0.25, freq, freq * 0.985,
                 gain * level, 4.5 + ratio)

    f = p["family"]
    retro = p.get("retro", False)
    if p.get("batch") == 2:
        notes = p["notes"]

        def chime(start, length, freq, gain, metallic=False):
            # Fundamental redonda; pocos parciales, colas cortas y sin brillo duro.
            tone(start, length, freq, freq * 0.998, gain, 3.2)
            tone(start, length * 0.68, freq * 2.01, freq * 2,
                 gain * (0.19 if metallic else 0.09), 5)
            if metallic:
                tone(start, length * 0.42, freq * 2.73, freq * 2.72,
                     gain * 0.07, 6)

        if f == "moneda_recoger":
            chime(0, duration * 0.65, notes[0], 0.65, metallic=True)
            chime(duration * 0.22, duration * 0.78, notes[1], 0.82, metallic=True)
        elif f == "objeto_recoger":
            for k, freq in enumerate(notes):
                start = duration * k * 0.25
                chime(start, duration - start, freq, 0.65 + k * 0.07)
        elif f == "dialogo_avanzar":
            tone(0, duration, notes[0], notes[0] * 0.83, 0.7, 7)
            noise(0, duration * 0.50, 750, 1100, 0.22, 7, width=0.4)
        elif f == "dialogo_abrir":
            tone(0, duration, notes[0], notes[1], 0.65, 5)
            noise(0, duration * 0.35, 650, 1100, 0.17, 6, width=0.4)
        elif f == "dialogo_letra":
            arcade(0, duration, notes[0], notes[0], 0.7, 2.5)
        elif f == "comer":
            # Crujido de fruta en pequeñas fracturas; después un trago abstracto,
            # con ruido grave y dos resonancias cortas, sin voz ni samples.
            noise(0, duration * 0.34, 1300, 2400, 0.95, 5, width=0.35)
            tone(0, duration * 0.18, 210, 140, 0.16, 6)
            for k in range(7):
                start = duration * (0.015 + k * 0.033) + rng.uniform(0, 0.006)
                noise(start, duration * rng.uniform(0.055, 0.11),
                      rng.uniform(1000, 1900), 2500, 0.7 * math.exp(-k * 0.18), 6, width=0.35)
            tone(duration * 0.52, duration * 0.40, notes[0], notes[1], 0.18, 4)
            tone(duration * 0.60, duration * 0.34, 160, 115, 0.11, 4)
            noise(duration * 0.50, duration * 0.48, 300, 520, 0.22, 3, swell=True, width=0.3)
        elif f == "curar":
            for k, freq in enumerate(notes):
                start = duration * k * 0.19
                length = duration - start
                chime(start, length, freq, 0.54 + k * 0.035)
                arcade(start, length, freq / 2, freq / 2, 0.11, 4)
        elif f == "menu_mover":
            tone(0, duration, notes[0], notes[0] * 0.90, 0.6, 6)
            noise(0, duration * 0.35, 1200, 1700, 0.08, 6)
        elif f == "menu_aceptar":
            chime(0, duration * 0.60, notes[0], 0.6)
            chime(duration * 0.34, duration * 0.66, notes[1], 0.7)
        elif f == "menu_volver":
            arcade(0, duration, notes[0], notes[1], 0.65, 3.5)
        else:
            raise ValueError(f"Familia del lote 2 desconocida: {f}")
    elif retro and f == "espada":
        # Filo de hierro: ataque metálico definido sobre el corte de aire.
        noise(0, duration * 0.75, 1500, 3200, 0.75, 1.8, swell=True)
        iron(0, duration * 0.88, 1680, 0.46)
        iron(duration * 0.045, duration * 0.68, 2150, 0.13)
        arcade(0, duration * 0.45, 1100, 1650, 0.055, 4)
    elif retro and f == "golpe_enemigo":
        arcade(0, duration * 0.85, 440, 155, 0.8, 6, pulse=True)
        tone(0, duration, 150, 95, 0.48, 6)
        noise(0, duration * 0.3, 1800, 2800, 0.85, 7, width=0.35)
        iron(0, duration * 0.55, 1380, 0.14)
    elif retro and f == "leonidas_caer":
        tone(0, duration * 0.28, 115, 65, 0.85, 5)
        noise(0, duration * 0.16, 500, 900, 0.65, 6, width=0.3)
        # Cadencia modal descendente, timbre de lira sintetizada + triángulo.
        # Evoca una aventura mítica; no pretende reconstruir música antigua.
        notes = (659.255, 587.330, 493.883, 440.000, 329.628)
        for k, freq in enumerate(notes):
            start = duration * k * 0.145
            length = duration * (0.23 if k < 4 else 0.40)
            gain = 0.30 if k < 4 else 0.25
            arcade(start, length, freq, freq * 0.997, gain, 3)
            tone(start, length, freq * 2, freq * 1.995, gain * 0.22, 6, harmonics=0.08)
    elif retro and f == "barco_golpe":
        arcade(0, duration * 0.38, 160, 65, 0.8, 5)
        tone(0, duration * 0.35, 98, 78, 0.75, 6, harmonics=0.25)
        noise(0, duration * 0.2, 450, 1000, 0.9, 6, width=0.25)
        for k in range(3):
            arcade(duration * k * 0.025, duration * 0.15,
                   260 + k * 65, 145, 0.12, 6, pulse=True)
        noise(duration * 0.07, duration * 0.44, 1800, 2600, 0.65, 3, swell=True)
        noise(duration * 0.22, duration * 0.7, 550, 950, 0.65, 3, swell=True)
        for k, freq in enumerate((740, 554, 370)):
            arcade(duration * (0.32 + k * 0.12), duration * 0.16,
                   freq, freq * 0.68, 0.10, 5)
    elif retro and f == "leonidas_danio":
        # Respuesta de consola más aguda que el golpe enemigo, sin voz.
        arcade(0, duration * 0.94, 880, 293.665, 0.58, 3.5, pulse=True)
        arcade(0, duration, 220, 110, 0.55, 5)
        tone(0, duration * 0.65, 330, 165, 0.28, 6)
        noise(0, duration * 0.28, 1500, 2400, 0.65, 7, width=0.35)
    elif f == "paso":
        tone(0, duration, 132, 94, 0.8, 5)
        noise(0, duration, 550, 800, 1.1, 5, width=0.3)
        noise(duration * 0.12, duration * 0.6, 1100, 700, 0.25, 5)
    elif f == "espada":
        noise(0, duration, 1200, 3000, 1.4, 1.4, swell=True)
        noise(0, duration, 650, 1000, 0.22, 2, swell=True)
    elif f == "vasija_romper":
        noise(0, 0.055, 2700, 3800, 1.7, 6, width=0.4)
        tone(0, 0.08, 640, 420, 0.5, 6, harmonics=0.2)
        for k in range(rng.randint(5, 8)):
            start = duration * (0.05 + k * 0.082) + rng.uniform(0, 0.018)
            freq = rng.uniform(1100, 3700)
            length = min(duration - start, rng.uniform(0.075, 0.14))
            gain = 0.5 * math.exp(-k * 0.20)
            tone(start, length, freq, freq * 0.96, gain, 7, harmonics=0.17)
            noise(start, length * 0.45, 2400, 1500, gain * 0.7, 5)
    elif f == "piedra_caer":
        tone(0, duration * 0.7, 105, 73, 1, 5, harmonics=0.13)
        noise(0, duration * 0.55, 480, 900, 1.1, 6, width=0.25)
        tone(duration * 0.66, duration * 0.30, 112, 88, 0.20, 6)
        noise(duration * 0.66, duration * 0.28, 700, 900, 0.2, 6)
    elif f == "golpe_enemigo":
        tone(0, duration * 0.85, 435, 310, 0.9, 8, harmonics=0.16)
        noise(0, duration * 0.55, 1900, 2800, 1.4, 8, width=0.35)
        tone(0, duration, 170, 130, 0.32, 7)
    elif f == "leonidas_caer":
        tone(0, duration * 0.34, 115, 68, 1, 5)
        noise(0, duration * 0.25, 500, 900, 1, 6, width=0.3)
        tone(0, duration * 0.94, 400, 120, 0.38, 2.7, harmonics=0.06)
        noise(duration * 0.14, duration * 0.26, 650, 1200, 0.2, 5)
    elif f == "barco_golpe":
        tone(0, duration * 0.5, 100, 80, 0.9, 6, harmonics=0.28)
        noise(0, duration * 0.35, 450, 1000, 1, 5, width=0.25)
        for k in range(4):
            tone(k * 0.012, duration * 0.22, rng.uniform(170, 300), 120, 0.18, 7, harmonics=0.25)
        # Dos bandas superpuestas bajan el centro espectral del chapoteo.
        noise(duration * 0.075, duration * 0.4, 2400, 3000, 0.8, 3, swell=True)
        noise(duration * 0.20, duration * 0.72, 650, 1100, 0.9, 3, swell=True)
        for k in range(3):
            start = duration * (0.4 + k * 0.10)
            tone(start, duration * 0.13, 700 - k * 110, 350 - k * 40, 0.07, 6)
    elif f == "leonidas_danio":
        tone(0, duration, 760, 330, 0.75, 4, harmonics=0.13)
        tone(0, duration * 0.8, 220, 135, 0.6, 6)
        noise(0, duration * 0.42, 1300, 2400, 0.8, 7, width=0.35)
    elif f == "voltereta":
        noise(0, duration * 0.9, 800, 2500, 0.9, 1.8, swell=True)
        noise(0, duration * 0.95, 320, 650, 0.6, 1.5, swell=True, width=0.35)
        tone(duration * 0.76, duration * 0.24, 130, 90, 0.38, 5)
        noise(duration * 0.76, duration * 0.24, 550, 900, 0.3, 5)
    else:
        raise ValueError(f"Familia desconocida: {f}")

    # Filtro común, eliminación de DC y fundidos de entrada submilisegundo y
    # salida de 8 ms. El primer frame cero es un cruce natural, no un preroll.
    signal = lowpass(signal, p["brightness"])
    dc = sum(signal) / n
    fade = round(0.008 * RATE)
    for i in range(n):
        signal[i] = (signal[i] - dc) * min(1.0, i / 22) * min(1.0, (n - 1 - i) / fade)
    peak = max(abs(x) for x in signal)
    scale = 32767 * 10 ** (p["peak_db"] / 20) / peak
    return [round(x * scale) for x in signal]


def verify(path, p):
    issues = []
    with wave.open(str(path), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) != (1, 2, RATE, "NONE"):
            issues.append("formato incorrecto")
        frames = wav.getnframes()
        samples = struct.unpack(f"<{frames}h", wav.readframes(frames))
    duration = frames / RATE
    peak = max(abs(x) for x in samples)
    db = 20 * math.log10(peak / 32768) if peak else -math.inf
    if not p["limits"][0] <= duration <= p["limits"][1]:
        issues.append("duración fuera de rango")
    if abs(db - p["peak_db"]) > 0.02:
        issues.append("pico incorrecto")
    if peak >= 32767:
        issues.append("clipping")
    if not any(abs(x) > 32 for x in samples[:round(RATE * 0.002)]):
        issues.append("ataque tardío")
    if samples[-1] != 0 or abs(samples[-2]) > 32:
        issues.append("final sin fundido")
    print(f"{path.name:25s} {duration * 1000:9.2f} {db:10.2f}  {'; '.join(issues) if issues else 'OK'}")
    return issues


def main():
    selected = set()
    for name in sys.argv[1:]:
        name = name.removesuffix(".wav")
        matches = [key for key, p in SONIDOS.items()
                   if key == name or p["family"] == name
                   or name == f"lote_{p.get('batch', 1)}"]
        if not matches:
            print(f"Sonido desconocido: {name}. Opciones: {', '.join(SONIDOS)}", file=sys.stderr)
            return 2
        selected.update(matches)
    if not sys.argv[1:]:
        selected = set(SONIDOS)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    print(f"{'Archivo':25s} {'ms':>9s} {'dBFS':>10s}  Verificación")
    failed = False
    for name, p in SONIDOS.items():
        if name not in selected:
            continue
        samples = synthesize(p)
        path = OUTPUT / f"{name}.wav"
        with wave.open(str(path), "wb") as wav:
            wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            wav.writeframes(struct.pack(f"<{len(samples)}h", *samples))
        failed |= bool(verify(path, p))
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
