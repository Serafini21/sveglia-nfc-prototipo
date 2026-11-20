"""Genera l'icona di Alba (PNG 1024x1024, opaca): un sole minimal che sorge, nei colori dell'app.

Solo libreria standard: forme disegnate con funzioni distanza e bordi sfumati di 1 px (antialias).
Uso: python genera_icona.py <file_png>
"""
import math
import struct
import sys
import zlib

LATO = 1024
SFONDO_ALTO = (0x0B, 0x10, 0x20)    # sfondo dell'app
SFONDO_BASSO = (0x1E, 0x26, 0x40)   # superficie 2, verso l'orizzonte
ACQUA = (0x15, 0x1B, 0x2E)          # superficie, sotto l'orizzonte
AMBRA = (0xFF, 0xB5, 0x47)          # accento

ORIZZONTE = 610
CX, RAGGIO = 512, 250
# riflesso: (y del centro, mezza larghezza, spessore)
STRISCE = [(680, 210, 22), (740, 150, 20), (796, 92, 18)]


def mescola(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def copertura(distanza):
    """Distanza con segno dal bordo (negativa dentro) -> copertura 0..1 con 1 px di sfumatura."""
    return max(0.0, min(1.0, 0.5 - distanza))


def capsula(x, y, cy, mezza, spessore):
    """Distanza con segno da una barra orizzontale con estremi arrotondati."""
    r = spessore / 2
    dx = max(abs(x - CX) - (mezza - r), 0.0)
    return math.hypot(dx, y - cy) - r


def pixel(x, y):
    px, py = x + 0.5, y + 0.5
    if py < ORIZZONTE:
        colore = mescola(SFONDO_ALTO, SFONDO_BASSO, (py / ORIZZONTE) ** 2)
        d = math.hypot(px - CX, py - ORIZZONTE)
        # alone caldo attorno al sole
        alone = max(0.0, 1 - (d - RAGGIO) / 260) ** 2 * 0.22 if d > RAGGIO else 0.0
        colore = mescola(colore, AMBRA, alone)
        # mezzo sole tagliato dall'orizzonte
        sole = copertura(d - RAGGIO) * copertura(py - ORIZZONTE)
        return mescola(colore, AMBRA, sole)
    colore = ACQUA
    for cy, mezza, spessore in STRISCE:
        colore = mescola(colore, AMBRA, copertura(capsula(px, py, cy, mezza, spessore)))
    return colore


def scrivi_png(percorso, righe):
    def blocco(tipo, dati):
        return struct.pack(">I", len(dati)) + tipo + dati + struct.pack(">I", zlib.crc32(tipo + dati) & 0xFFFFFFFF)
    grezzo = b"".join(b"\x00" + bytes(r) for r in righe)
    png = b"\x89PNG\r\n\x1a\n" + blocco(b"IHDR", struct.pack(">IIBBBBB", LATO, LATO, 8, 2, 0, 0, 0))
    png += blocco(b"IDAT", zlib.compress(grezzo, 9)) + blocco(b"IEND", b"")
    with open(percorso, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    destinazione = sys.argv[1] if len(sys.argv) > 1 else "icona.png"
    righe = []
    for y in range(LATO):
        riga = []
        for x in range(LATO):
            riga.extend(int(round(c)) for c in pixel(x, y))
        righe.append(riga)
    scrivi_png(destinazione, righe)
    # auto-verifica: angoli scuri (sfondo), centro del sole ambra, sotto l'orizzonte acqua
    assert righe[0][0:3] == list(SFONDO_ALTO)
    assert righe[ORIZZONTE - 40][CX * 3:CX * 3 + 3] == list(AMBRA)
    assert righe[LATO - 1][0:3] == list(ACQUA)
    print(f"{destinazione}: {LATO}x{LATO}")
