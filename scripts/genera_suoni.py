"""Genera i suoni di Alba (WAV PCM 16 bit mono, 22.050 Hz) usando solo la libreria standard.

File brevi: AlarmKit li ripete in loop finche' la sveglia non viene fermata (verificato col prototipo),
cosi' l'IPA resta leggera. La progressiva usa lo stesso suono dolce in 15 livelli pre-calcolati,
da circa -30 dB (livello 1) a 0 dB (livello 15).

Uso: python genera_suoni.py <cartella_destinazione>
"""
import math
import os
import struct
import sys
import wave

RATE = 22050  # basta per suonerie, dimezza il peso rispetto a 44.1 kHz
PICCO = 0.95  # margine per non saturare
LIVELLI = 15


def db_livello(i):
    """dB del livello i (1..15) della progressiva: da -30 a 0 a passi di circa 2,14 dB."""
    return -30.0 + (i - 1) * 30.0 / (LIVELLI - 1)


def scrivi(path, campioni, guadagno=1.0):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * guadagno)) * 32767)) for s in campioni))


def normalizza(campioni):
    picco = max(abs(s) for s in campioni)
    return [PICCO * s / picco for s in campioni]


def dolce(secondi=4.0):
    """Carillon morbido: due note che sfumano, ripetute ogni 2 s."""
    note = [(0.0, 1046.5), (0.5, 1318.5), (2.0, 1046.5), (2.5, 1568.0)]
    out = []
    for n in range(int(secondi * RATE)):
        t = n / RATE
        s = 0.0
        for inizio, f in note:
            dt = t - inizio
            if 0 <= dt < 1.5:
                attacco = min(1.0, dt / 0.01)  # niente click all'inizio della nota
                s += attacco * math.exp(-3.0 * dt) * (math.sin(2 * math.pi * f * dt) + 0.3 * math.sin(4 * math.pi * f * dt))
        out.append(s)
    return normalizza(out)


def normale(secondi=4.0):
    """Bip-bip doppio a 880 Hz con armonica (la suoneria del prototipo, in loop da 4 s)."""
    out = []
    for n in range(int(secondi * RATE)):
        t = n / RATE
        fase = t % 1.0
        acceso = fase < 0.15 or 0.25 <= fase < 0.40
        out.append(0.7 * math.sin(2 * math.pi * 880 * t) + 0.2 * math.sin(2 * math.pi * 1760 * t) if acceso else 0.0)
    return normalizza(out)


def energica(secondi=3.0):
    """Tre bip rapidi e acuti ogni 0,75 s."""
    out = []
    for n in range(int(secondi * RATE)):
        t = n / RATE
        fase = t % 0.75
        acceso = any(a <= fase < a + 0.08 for a in (0.0, 0.12, 0.24))
        out.append(0.6 * math.sin(2 * math.pi * 1320 * t) + 0.3 * math.sin(2 * math.pi * 2640 * t) if acceso else 0.0)
    return normalizza(out)


def punizione(secondi=4.2):
    """Sirena acuta a spazzata veloce (700-1600 Hz ogni 0,35 s) con onda quadra: martellante.
    Diversa dall'IT-alert (tono fisso modulato). 4,2 s = multiplo di 0,35 e 0,12, cosi' il loop non si sente."""
    out = []
    fase = 0.0
    for n in range(int(secondi * RATE)):
        t = n / RATE
        p = (t % 0.35) / 0.35
        f = 700 + 900 * (p * 2 if p < 0.5 else (1 - p) * 2)
        fase += 2 * math.pi * f / RATE
        quadra = 1.0 if math.sin(fase) >= 0 else -1.0
        martello = 1.0 if (t % 0.12) < 0.09 else 0.3
        out.append(martello * (0.6 * quadra + 0.4 * math.sin(fase)))
    return normalizza(out)


def picco(path):
    with wave.open(path) as w:
        dati = w.readframes(w.getnframes())
    return max(abs(v[0]) for v in struct.iter_unpack("<h", dati))


if __name__ == "__main__":
    dest = sys.argv[1] if len(sys.argv) > 1 else "Sounds"
    os.makedirs(dest, exist_ok=True)

    suoni = {"dolce.wav": dolce(), "normale.wav": normale(), "energica.wav": energica(), "punizione.wav": punizione()}
    for nome, campioni in suoni.items():
        scrivi(os.path.join(dest, nome), campioni)

    base = suoni["dolce.wav"]
    for i in range(1, LIVELLI + 1):
        scrivi(os.path.join(dest, f"dolce_{i:02d}.wav"), base, 10 ** (db_livello(i) / 20))

    # Auto-verifica: formato, durata, livelli crescenti e rapporto tra il primo e l'ultimo (30 dB)
    totale = 0
    for nome in sorted(os.listdir(dest)):
        path = os.path.join(dest, nome)
        with wave.open(path) as w:
            assert w.getframerate() == RATE and w.getnchannels() == 1 and w.getsampwidth() == 2, nome
            assert 2.9 < w.getnframes() / RATE < 4.3, nome
        totale += os.path.getsize(path)
    picchi = [picco(os.path.join(dest, f"dolce_{i:02d}.wav")) for i in range(1, LIVELLI + 1)]
    assert all(a < b for a, b in zip(picchi, picchi[1:])), picchi
    rapporto_db = 20 * math.log10(picchi[-1] / picchi[0])
    assert abs(rapporto_db - 30) < 0.5, rapporto_db
    print(f"{len(os.listdir(dest))} suoni, {totale // 1024} KB in tutto; progressiva da {db_livello(1):.0f} a {db_livello(LIVELLI):.0f} dB "
          f"(misurati {rapporto_db:.1f} dB di differenza)")
