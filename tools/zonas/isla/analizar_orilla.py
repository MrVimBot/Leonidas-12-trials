#!/usr/bin/env python3
"""Saca del fondo pintado de la playa de la isla la colisión de la zona `isla_orilla` (nivel 2).

    python3 tools/zonas/isla/analizar_orilla.py          # escribe tools/zonas/isla/orilla_datos.json
    python3 tools/zonas/isla/analizar_orilla.py --vista  # además, una imagen de control en /tmp

Lo usa `montar_orilla.gd` (una sola vez, como la isla: ver analizar_isla.py). El fondo
(assets/backgrounds/nivel2/playa_entero_fondo.png, 4960×3508) va a escala 0,125 → 620×438 px de
mundo. Se trabaja en una rejilla de 1/16 del lienzo = 2 px de mundo por celda, la misma que la
isla, así que se reutilizan sus funciones de polígonos.

Transitable = la arena + el muelle. El agua (con la espuma de la orilla), la barca y la mata de
hierba de la esquina no se pisan; el borde del mapa tampoco (las salidas están encima).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

import analizar_isla as isla

RAIZ = Path(__file__).resolve().parents[3]
FONDO = RAIZ / "assets/backgrounds/nivel2/playa_entero_fondo.png"
SALIDA = Path(__file__).with_name("orilla_datos.json")
LIENZO = (4960, 3508)
ESCALA = 0.125
W, H = LIENZO[0] // 16, LIENZO[1] // 16
assert 16 * ESCALA == isla.PX, "la rejilla debe ser la de analizar_isla.py (2 px de mundo por celda)"
# Muelle (celdas): rectángulo de tablas que entra en el agua desde el borde superior.
MUELLE = (130, 0, 188, 44)  # x0, y0, x1, y1
# Barca pintada junto al muelle (no se pisa).
BARCA = (192, 0, 240, 28)


def main():
    c = np.array(Image.open(FONDO).convert("RGB").resize((W, H), Image.BILINEAR)).astype(int)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    # Agua y espuma tienen más verde que rojo; la arena, al revés.
    agua = g > r + 5
    agua = ndi.binary_closing(agua, iterations=2)
    agua = ndi.binary_opening(agua, iterations=2)
    # Lo de arriba que no es arena ni muelle (la barca, la espuma clara) también es agua.
    arena = ~agua
    lab, n = ndi.label(arena)
    yy, xx = np.mgrid[0:H, 0:W]
    muelle = (xx >= MUELLE[0]) & (xx <= MUELLE[2]) & (yy >= MUELLE[1]) & (yy <= MUELLE[3])
    principal = lab == lab[H - 10, W // 2]
    barca = (xx >= BARCA[0]) & (xx <= BARCA[2]) & (yy >= BARCA[1]) & (yy <= BARCA[3])
    trans = (principal | muelle) & ~barca
    # Estrellas y conchas pintadas en la arena no estorban: se rellenan los huecos pequeños
    # (binary_fill_holes no sirve: el cierre de arriba despega el agua del borde superior).
    huecos, n = ndi.label(~trans)
    tam = ndi.sum(~trans, huecos, range(1, n + 1))
    for i, v in enumerate(tam):
        if v < 400:
            trans[huecos == i + 1] = True
    trans[:2, :] = trans[-2:, :] = False
    trans[:, :2] = trans[:, -2:] = False
    datos = {
        "tamano": [round(LIENZO[0] * ESCALA), round(LIENZO[1] * ESCALA)],
        "escala": ESCALA,
        "costa": isla.poligonos_solidos(~trans),
    }
    SALIDA.write_text(json.dumps(datos, indent=1))
    print(f"costa {len(datos['costa'])} polígonos")
    if "--vista" in sys.argv:
        img = (c * 0.5).astype(np.uint8)
        img[trans] = (200, 190, 120)
        Image.fromarray(img).save("/tmp/orilla_vista.png")


if __name__ == "__main__":
    main()
