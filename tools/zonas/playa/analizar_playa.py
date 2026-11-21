#!/usr/bin/env python3
"""Prepara la zona `playa` (nivel 1) a partir del dibujo de la artista
assets/backgrounds/playa/playa.aseprite (500×400, pixel art, una capa por tipo de cosa).

    python3 tools/zonas/playa/analizar_playa.py           # PNG + tools/zonas/playa/playa_datos.json
    python3 tools/zonas/playa/analizar_playa.py --vista   # además, /tmp/playa_vista.png

Necesita la CLI de Aseprite (variable ASEPRITE, `aseprite` en el PATH o la compilación local,
como tools/export_sprites.sh) y numpy, scipy, scikit-image y Pillow. Trabaja sobre una copia del
.aseprite. Lo usa `montar_playa.gd`; volver a ejecutarlo si la artista cambia el dibujo.

Escala 1: 1 px del dibujo = 1 px de mundo (como el resto del nivel 1).
- Fondo (assets/backgrounds/playa/playa_fondo.png): capas de suelo (pasto, arena, agua, muelle,
  barca) más los objetos pequeños de las capas de objetos (piedrecitas, flores): no tapan a nadie.
- Objetos (assets/sprites/entorno/playa/*.png): cada mancha de las capas «assets de bosque» y
  «palmeras» (árboles, rocas, troncos, arbustos, palmeras) recortada aparte para ordenarse por Y
  con Leonidas: `ancla` = centro de su pie (filas más bajas).
- Colisión (polígonos, como la isla): agua (salvo el muelle), barca, borde del mapa y el pie de
  cada objeto: en las palmeras, el tronco; en lo demás, el 40 % más bajo de cada columna del
  dibujo (al menos 10 px): la base de los árboles, la roca, el tronco caído… Con solo una franja
  fina, Leonidas se metía por detrás de las copas y desaparecía.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "isla"))
import analizar_isla as isla  # noqa: E402  (polígonos por trozos)

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/backgrounds/playa/playa.aseprite"
FONDO = RAIZ / "assets/backgrounds/playa/playa_fondo.png"
DIR_OBJETOS = RAIZ / "assets/sprites/entorno/playa"
SALIDA = Path(__file__).with_name("playa_datos.json")
SUELO = ["pasto", "arena", "agua tiles", "muelle", "barco"]  # de abajo arriba
OBJETOS = ["assets de bosque", "palmeras"]
MINIMO_OBJETO = 120  # px opacos: lo más pequeño se queda en el fondo
PIE = 10  # px mínimos de cada columna que cuentan como pie (objetos que no son palmeras)


def aseprite():
    return os.environ.get("ASEPRITE") or shutil.which("aseprite") \
        or str(Path.home() / "Developer/aseprite/build/bin/aseprite")


def exportar_capas(tmp):
    copia = Path(tmp) / "copia.aseprite"
    shutil.copy(FUENTE, copia)
    capas = {}
    for nombre in SUELO + OBJETOS:
        png = Path(tmp) / (nombre.replace(" ", "_") + ".png")
        subprocess.run([aseprite(), "-b", "--layer", nombre, str(copia), "--save-as", str(png)],
                       check=True, capture_output=True)
        capas[nombre] = Image.open(png).convert("RGBA")
    return capas


def separar_palmeras(rgba, lab, n):
    """Palmeras cuyas copas se tocan forman una sola mancha: se parte en una por tronco (manchas
    marrones), dando cada píxel a la palmera con el tronco más cercano. Devuelve otra rejilla de
    etiquetas (una por palmera)."""
    r, g = rgba[..., 0].astype(int), rgba[..., 1].astype(int)
    marron = (lab > 0) & (r > g + 15)
    troncos, m = ndi.label(marron, structure=np.ones((3, 3)))
    tam = ndi.sum(marron, troncos, range(1, m + 1))
    grandes = [i + 1 for i, v in enumerate(tam) if v >= 40]
    nueva = np.zeros_like(lab)
    siguiente = 1
    for k in range(1, n + 1):
        mancha = lab == k
        suyos = [t for t in grandes if (mancha & (troncos == t)).any()]
        if len(suyos) <= 1:
            nueva[mancha] = siguiente
            siguiente += 1
            continue
        # Distancia de cada píxel a cada tronco; se queda con el más cercano.
        dist = np.stack([ndi.distance_transform_edt(troncos != t) for t in suyos])
        cerca = np.argmin(dist, axis=0)
        for j in range(len(suyos)):
            nueva[mancha & (cerca == j)] = siguiente
            siguiente += 1
    return nueva


def main():
    with tempfile.TemporaryDirectory() as tmp:
        capas = exportar_capas(tmp)
    w, h = capas["pasto"].size
    fondo = Image.new("RGBA", (w, h))
    for nombre in SUELO:
        fondo.alpha_composite(capas[nombre])

    DIR_OBJETOS.mkdir(parents=True, exist_ok=True)
    for viejo in DIR_OBJETOS.glob("*.png"):
        viejo.unlink()
    objetos = []
    pies = np.zeros((h, w), bool)
    for nombre in OBJETOS:
        img = capas[nombre]
        alfa = np.array(img)[..., 3] > 0
        lab, n = ndi.label(alfa, structure=np.ones((3, 3)))
        if nombre == "palmeras":
            lab = separar_palmeras(np.array(img), lab, n)
        for i, sl in enumerate(ndi.find_objects(lab), start=1):
            if sl is None:
                continue
            mancha = lab[sl] == i
            if mancha.sum() < MINIMO_OBJETO:
                # Pequeño: al fondo.
                trozo = Image.fromarray(np.where(mancha[..., None], np.array(img)[sl], 0).astype(np.uint8))
                fondo.alpha_composite(trozo, (sl[1].start, sl[0].start))
                continue
            y0, x0 = sl[0].start, sl[1].start
            recorte = np.where(mancha[..., None], np.array(img)[sl], 0).astype(np.uint8)
            alto, ancho = mancha.shape
            abajo = np.nonzero(mancha.any(1))[0].max()
            franja = mancha[max(abajo - max(int(alto * 0.04), 1), 0):abajo + 1]
            cols = np.nonzero(franja.any(0))[0]
            ancla = [int(round((cols.min() + cols.max() + 1) / 2)), int(abajo + 1)]
            tipo = "palmera" if nombre == "palmeras" else "objeto"
            archivo = f"{tipo}_{len(objetos) + 1}.png"
            Image.fromarray(recorte).save(DIR_OBJETOS / archivo)
            objetos.append({"textura": archivo, "pos": [x0 + ancla[0], y0 + ancla[1]], "ancla": ancla,
                            "tipo": tipo})
            # Pie para la colisión.
            if tipo == "palmera":
                tronco = max(int((cols.max() - cols.min() + 1) * 0.7), 6)
                cx = x0 + ancla[0]
                pies[y0 + abajo - 6:y0 + abajo + 1, cx - tronco // 2:cx + (tronco + 1) // 2] = True
            else:
                for c in range(ancho):
                    ys = np.nonzero(mancha[:, c])[0]
                    if len(ys):
                        fondo_col = ys.max()
                        alto_pie = max(PIE, int((fondo_col - ys.min() + 1) * 0.4))
                        pies[y0 + max(fondo_col - alto_pie + 1, ys.min()):y0 + fondo_col + 1, x0 + c] = True
    fondo.save(FONDO)

    agua = np.array(capas["agua tiles"])[..., 3] > 0
    muelle = np.array(capas["muelle"])[..., 3] > 0
    barca = np.array(capas["barco"])[..., 3] > 0
    solido = (agua & ~muelle) | barca | pies
    solido = ndi.binary_closing(solido, iterations=1) | barca
    solido[:2, :] = solido[-2:, :] = True
    solido[:, :2] = solido[:, -2:] = True
    isla.PX = 1.0  # aquí 1 celda = 1 px de mundo
    datos = {"tamano": [w, h], "objetos": objetos, "costa": isla.poligonos_solidos(solido)}
    SALIDA.write_text(json.dumps(datos, indent=1))
    print(f"{len(objetos)} objetos, costa {len(datos['costa'])} polígonos → {SALIDA.name}")
    if "--vista" in sys.argv:
        vista = np.array(fondo.convert("RGB")) // 2
        vista[solido] = (255, 0, 0)
        Image.fromarray(vista.astype(np.uint8)).resize((w * 2, h * 2), Image.NEAREST).save("/tmp/playa_vista.png")


if __name__ == "__main__":
    main()
