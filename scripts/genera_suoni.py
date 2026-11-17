"""Genera i suoni della sveglia (WAV PCM 16 bit mono) usando solo la libreria standard.

Uso: python genera_suoni.py <cartella_destinazione>
"""
import math
import os
import struct
import sys
import wave

RATE = 22050  # basta per suonerie, dimezza il peso rispetto a 44.1 kHz


def scrivi(path, campioni):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in campioni))


def normale(secondi=25):
    """Bip-bip doppio a 880 Hz con armonica, gradevole ma deciso."""
    out = []
    for n in range(int(secondi * RATE)):
        t = n / RATE
        fase = t % 1.0
        acceso = fase < 0.15 or 0.25 <= fase < 0.40
        s = 0.0
        if acceso:
            s = 0.7 * math.sin(2 * math.pi * 880 * t) + 0.2 * math.sin(2 * math.pi * 1760 * t)
        out.append(s)
    return out


def punizione(secondi=25):
    """Sirena acuta a spazzata veloce (700-1600 Hz ogni 0,35 s) con onda quadra: martellante.
    Diversa dall'IT-alert (che e' un tono fisso modulato), qui la frequenza sale e scende di continuo."""
    out = []
    fase = 0.0
    for n in range(int(secondi * RATE)):
        t = n / RATE
        p = (t % 0.35) / 0.35
        f = 700 + 900 * (p * 2 if p < 0.5 else (1 - p) * 2)
        fase += 2 * math.pi * f / RATE
        quadra = 1.0 if math.sin(fase) >= 0 else -1.0
        martello = 1.0 if (t % 0.12) < 0.09 else 0.3
        out.append(0.9 * martello * (0.6 * quadra + 0.4 * math.sin(fase)))
    return out


def lungo(secondi=180):
    """Tono a volume crescente per 3 minuti. Ogni 30 s fa N bip veloci (N = mezzi minuti trascorsi),
    cosi' ascoltando si capisce fin dove arriva il suono o se ricomincia da capo (torna piano)."""
    out = []
    for n in range(int(secondi * RATE)):
        t = n / RATE
        vol = 0.05 + 0.85 * (t / secondi)
        blocco = int(t // 30)
        dentro = t - blocco * 30
        if blocco > 0 and dentro < blocco * 0.3 and (dentro % 0.3) < 0.15:
            s = 0.95 * math.sin(2 * math.pi * 1500 * t)  # marcatore a volume pieno
        else:
            s = vol * math.sin(2 * math.pi * 520 * t) * (0.6 + 0.4 * math.sin(2 * math.pi * 2 * t))
        out.append(s)
    return out


SUONI = {"suoneria_normale.wav": (normale, 25), "suoneria_punizione.wav": (punizione, 25), "test_lungo_3min.wav": (lungo, 180)}

if __name__ == "__main__":
    dest = sys.argv[1] if len(sys.argv) > 1 else "Sounds"
    os.makedirs(dest, exist_ok=True)
    for nome, (fn, durata) in SUONI.items():
        path = os.path.join(dest, nome)
        scrivi(path, fn(durata))
        with wave.open(path) as w:  # auto-verifica: durata e formato attesi
            assert w.getframerate() == RATE and w.getnchannels() == 1
            assert abs(w.getnframes() / RATE - durata) < 0.01, nome
        print(f"{nome}: {durata} s, {os.path.getsize(path) // 1024} KB")
