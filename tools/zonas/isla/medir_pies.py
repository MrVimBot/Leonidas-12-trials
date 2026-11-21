#!/usr/bin/env python3
"""Mide dónde toca el suelo cada objeto pintado del nivel 2 (assets/sprites/entorno/nivel2/).

    python3 tools/zonas/isla/medir_pies.py   # escribe tools/zonas/isla/pies.json

Los dibujos no siempre tienen el pie centrado ni pegado al borde inferior (palmeras inclinadas,
margen vacío debajo): si se colocan por el centro de la base de la imagen, la colisión y la
sombra quedan al lado del tronco. Por cada PNG:
- `ancla`: centro del pie (las filas opacas más bajas, el 4 % inferior del dibujo) en px de la
  textura → `Decorado.ancla`.
- `ancho_pie`: ancho de ese pie (tronco, base de la estatua…), en px de la textura.
- `caja`: rectángulo opaco del dibujo [x0, y0, x1, y1] (las rocas usan su ancho y alto).
- `tamano`: ancho y alto de la textura.
Lo usa tools/zonas/zona_pintada.gd (`opciones_pie`).
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[3]
DIR = RAIZ / "assets/sprites/entorno/nivel2"
SALIDA = Path(__file__).with_name("pies.json")


def main():
    datos = {}
    for png in sorted(DIR.glob("*.png")):
        a = np.array(Image.open(png).convert("RGBA"))[..., 3] > 128
        ys = np.nonzero(a.any(1))[0]
        xs = np.nonzero(a.any(0))[0]
        abajo = int(ys.max())
        franja = a[max(abajo - int(a.shape[0] * 0.04), 0):abajo + 1]
        px = np.nonzero(franja.any(0))[0]
        datos[png.stem] = {
            "tamano": [a.shape[1], a.shape[0]],
            "ancla": [round((px.min() + px.max() + 1) / 2), abajo + 1],
            "ancho_pie": int(px.max() - px.min() + 1),
            "caja": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, abajo + 1],
        }
    SALIDA.write_text(json.dumps(datos, indent=1))
    print(f"{len(datos)} objetos → {SALIDA.name}")


if __name__ == "__main__":
    main()
