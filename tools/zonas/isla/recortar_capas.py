#!/usr/bin/env python3
"""Recorta los márgenes transparentes de las capas del mapa de la isla (assets/backgrounds/nivel2/).

    python3 tools/zonas/isla/recortar_capas.py

La artista entregó las cinco capas con el mismo lienzo (9828×5873), pero `orilla`, `monte_1` y
`monte_2` son casi todo transparencia (`monte_2` dibuja el 2 % del lienzo) y cargar esos píxeles
vacíos costaba ~0,5 s al entrar en la isla. Cada capa se recorta a su dibujo (esquina redondeada
hacia abajo a múltiplos de 4, para que en el mundo, a escala 0,25, quede en px enteros) y su
esquina se apunta en `capas_recorte.json` (px del lienzo): el Sprite2D de la capa va en
esquina × 0,25. Solo recorta las que aún miden el lienzo entero, así que se puede repetir sin
perder la esquina; si la artista entrega capas nuevas, copiarlas encima y volver a ejecutarlo.
`analizar_isla.py` las vuelve a poner en su sitio con este mismo JSON.
"""
import json
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[3]
DIR = RAIZ / "assets/backgrounds/nivel2"
CAPAS = ["mar", "piso", "orilla", "monte_1", "monte_2"]
LIENZO = (9828, 5873)
SALIDA = Path(__file__).with_name("capas_recorte.json")


def main():
    esquinas = json.loads(SALIDA.read_text()) if SALIDA.exists() else {}
    for nombre in CAPAS:
        ruta = DIR / f"{nombre}.png"
        im = Image.open(ruta)
        if im.size != LIENZO:
            print(f"{nombre}: ya recortada ({im.size[0]}×{im.size[1]}, esquina {esquinas.get(nombre)})")
            continue
        x0, y0, x1, y1 = im.getbbox()
        x0, y0 = x0 // 4 * 4, y0 // 4 * 4
        if (x0, y0, x1, y1) == (0, 0, *LIENZO):
            esquinas[nombre] = [0, 0]
            print(f"{nombre}: sin márgenes, se queda igual")
            continue
        im.crop((x0, y0, x1, y1)).save(ruta, optimize=True)
        esquinas[nombre] = [x0, y0]
        print(f"{nombre}: {x1 - x0}×{y1 - y0} desde ({x0}, {y0})")
    SALIDA.write_text(json.dumps(esquinas, indent=1))


if __name__ == "__main__":
    main()
