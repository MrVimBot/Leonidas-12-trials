#!/usr/bin/env python3
"""Analiza el arte del laberinto del Minotauro (nivel 3, PROVISIONAL) y escribe
tools/zonas/laberinto/laberinto_datos.json, que lee montar_laberinto.gd.

    python3 tools/zonas/laberinto/analizar_laberinto.py

Entrada (entrega de la artista del 2026-11-22, lienzo 3223×1994):
  fuente/nivel3/laberinto/suelo.png     capa «fondo» (el suelo de losas)       } fuera de git,
  fuente/nivel3/laberinto/paredes.png   capa «paredes» (muros y sus caras)      } como fuente/nivel2
  assets/backgrounds/nivel3/laberinto/mapa.png   capa «antorchas» = el dibujo entero (suelo,
                                                  muros y pedestales con sus aros dorados)

Salida (px de MUNDO, escala ESCALA):
  solidos     rectángulos [x, y, ancho, alto] que no se pisan: todo lo que no es suelo libre
              (muros, sus caras dibujadas y lo de fuera del suelo). Se sacan de una rejilla de
              REJILLA px uniendo tramos iguales de filas seguidas: son convexos, así Godot no
              tiene que partir polígonos cóncavos (en el pasillo de Medusa su partición invadía
              el suelo libre).
  pedestales  rectángulos [x, y, ancho, alto] del pie de los pedestales con aro (están pintados
              sobre el suelo: no salen de la capa de paredes).
  aros        centros [x, y] de los aros dorados (antorchas): ahí van las luces.
  dibujo      [x, y, ancho, alto] de lo dibujado (límites de la cámara).
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

RAIZ = Path(__file__).resolve().parents[3]
SUELO = RAIZ / "fuente/nivel3/laberinto/suelo.png"
PAREDES = RAIZ / "fuente/nivel3/laberinto/paredes.png"
MAPA = RAIZ / "assets/backgrounds/nivel3/laberinto/mapa.png"
SALIDA = RAIZ / "tools/zonas/laberinto/laberinto_datos.json"

## Px de mundo por px del lienzo. Con 0,3 los pasillos miden 35–60 px de mundo (Leonidas
## mide ~25 de alto) y las losas, ~20 px, cerca de los tiles de 16 del nivel 1.
ESCALA = 0.3
## Lado de la celda de la rejilla de colisión (px de mundo).
REJILLA = 2
## Alfa mínimo para contar un píxel como dibujado.
ALFA = 40
## Cierre (px del lienzo) para tapar rendijas de 2–3 px entre trozos de muro pintados.
CIERRE = 12
## Cuánto se encoge la colisión respecto a lo pintado (px del lienzo; 7 ≈ 2 px de mundo). El único
## paso a la salida de abajo es una rendija de ~12 px de mundo entre la cara de un muro y el de
## abajo (x 175–230, y 398–407): con la colisión justa Leonidas (10×6) pasaba con 1 px de holgura
## y se enganchaba. Encogida, el paso es más holgado y los muros siguen tapando lo que se dibuja.
ENCOGER = 7


def alfa(ruta):
    return np.array(Image.open(ruta).convert("RGBA"))[..., 3] > ALFA


def a_rejilla(mascara, ancho, alto):
    """Solido por celda de REJILLA px de mundo: la celda es sólida si lo es más de la mitad."""
    img = Image.fromarray((mascara * 255).astype(np.uint8))
    img = img.resize((ancho // REJILLA, alto // REJILLA), Image.BOX)
    return np.array(img) > 127


def rectangulos(rejilla):
    """Une las celdas sólidas en rectángulos: tramos de cada fila y, mientras la fila de abajo
    tenga el mismo tramo, lo alarga hacia abajo."""
    abiertos = {}  # (x0, x1) -> [x0, y0, x1, y1]
    hechos = []
    filas, cols = rejilla.shape
    for y in range(filas + 1):
        tramos = set()
        if y < filas:
            fila = rejilla[y]
            x = 0
            while x < cols:
                if fila[x]:
                    x0 = x
                    while x < cols and fila[x]:
                        x += 1
                    tramos.add((x0, x))
                else:
                    x += 1
        for clave in list(abiertos):
            if clave in tramos:
                abiertos[clave][3] = y + 1
                tramos.discard(clave)
            else:
                hechos.append(abiertos.pop(clave))
        for t in tramos:
            abiertos[t] = [t[0], y, t[1], y + 1]
    return [[r[0] * REJILLA, r[1] * REJILLA, (r[2] - r[0]) * REJILLA, (r[3] - r[1]) * REJILLA]
            for r in hechos]


def aros_dorados(mapa_rgba):
    r, g, b, a = (mapa_rgba[..., i].astype(int) for i in range(4))
    oro = (a > 200) & (r > 140) & (g > 130) & (b < 120) & (r - b > 60)
    etiquetas, _ = ndi.label(ndi.binary_dilation(oro, iterations=4))
    res = []
    for i, trozo in enumerate(ndi.find_objects(etiquetas)):
        if (etiquetas[trozo] == i + 1).sum() < 150:
            continue
        cy = (trozo[0].start + trozo[0].stop) / 2 * ESCALA
        cx = (trozo[1].start + trozo[1].stop) / 2 * ESCALA
        ancho = (trozo[1].stop - trozo[1].start) * ESCALA
        res.append({"centro": [round(cx), round(cy)], "ancho": round(ancho)})
    return res


def main():
    suelo = alfa(SUELO)
    paredes = alfa(PAREDES)
    mapa = np.array(Image.open(MAPA).convert("RGBA"))
    alto_l, ancho_l = suelo.shape
    libre = suelo & ~paredes
    # Rendijas finas entre trozos de muro: se tapan (el muro "se cierra") para que nadie pase.
    solido = ndi.binary_closing(~libre, structure=np.ones((CIERRE, CIERRE)), border_value=1)
    solido = ndi.binary_erosion(solido, iterations=ENCOGER, border_value=1)
    ancho = int(round(ancho_l * ESCALA))
    alto = int(round(alto_l * ESCALA))
    ancho -= ancho % REJILLA
    alto -= alto % REJILLA
    rejilla = a_rejilla(solido, ancho, alto)
    solidos = rectangulos(rejilla)

    aros = aros_dorados(mapa)
    # Los aros pequeños (≤ 16 px) están sobre un pedestal pintado en el suelo: su pie es sólido.
    # Los grandes son aros del suelo y ya están en la capa de paredes.
    pedestales = []
    for aro in aros:
        if aro["ancho"] <= 20:
            x, y = aro["centro"]
            pedestales.append([x - 7, y + 2, 14, 12])

    ys, xs = np.nonzero(mapa[..., 3] > ALFA)
    dibujo = [round(xs.min() * ESCALA), round(ys.min() * ESCALA),
              round((xs.max() - xs.min()) * ESCALA), round((ys.max() - ys.min()) * ESCALA)]

    datos = {
        "escala": ESCALA,
        "tam": [ancho, alto],
        "dibujo": dibujo,
        "solidos": solidos,
        "pedestales": pedestales,
        "aros": [a["centro"] for a in aros],
    }
    SALIDA.write_text(json.dumps(datos, indent=1))
    print(f"{len(solidos)} rectángulos sólidos, {len(aros)} aros, {len(pedestales)} pedestales")
    print(f"mundo {ancho}×{alto}, dibujo {dibujo}")


if __name__ == "__main__":
    main()
