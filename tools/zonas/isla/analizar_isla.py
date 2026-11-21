#!/usr/bin/env python3
"""Saca del arte pintado y de los layouts de la artista los datos de la zona `isla` (nivel 2).

    python3 tools/zonas/isla/analizar_isla.py          # escribe tools/zonas/isla/isla_datos.json
    python3 tools/zonas/isla/analizar_isla.py --vista  # además, una imagen de control en /tmp

Necesita numpy, scipy, scikit-image y Pillow. Lo usa `montar_isla.gd` (una sola vez: la zona
queda marcada `editada_a_mano` y se retoca en el editor). Solo hay que volver a ejecutarlo si la
artista cambia las capas del mapa o los layouts.

Qué hace (todo en una rejilla de 1/8 del lienzo = 2 px de mundo por celda; el mapa va a escala
0,25, así que 1 px de mundo = 4 px del lienzo de 9828×5873):
- Transitable = `piso` + la hierba (verde) de `orilla` (la «U» elevada del sur) y de `monte_*`
  (la elevación del noroeste). El acantilado (marrón) de esas capas y el mar no se pisan.
- Elevaciones (layout «Elevaciones_entradas»): entre una elevación y el suelo de al lado hay una
  pared fina, salvo en los círculos naranjas (ABERTURAS). La franja de `orilla` al norte de
  CIERRE (borde oeste) no es la «U»: es costa y no se pisa.
- Colisión de costa y bordes: polígonos de lo NO transitable, por trozos (un polígono simple sin
  agujeros por componente y trozo, para que se puedan editar en el editor).
- Bosques (manchas rojas del layout): un polígono por mancha, recortado al suelo (no tapa las
  elevaciones).
- Puntos azules (enemigos) y amarillos (cofres), movidos al sitio libre más cercano si caen en
  algo sólido.
Los layouts son el mapa entero estirado a su tamaño (comprobado superponiéndolos).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure

RAIZ = Path(__file__).resolve().parents[3]
CAPAS = RAIZ / "assets/backgrounds/nivel2"
LAYOUTS = RAIZ / "docs/reference/nivel2/layout"
SALIDA = Path(__file__).with_name("isla_datos.json")

LIENZO = (9828, 5873)
ESCALA_MAPA = 0.25
W, H = LIENZO[0] // 8, LIENZO[1] // 8  # rejilla de trabajo: 1228×734
PX = 8 * ESCALA_MAPA  # px de mundo por celda (2)

CIERRE = 340  # fila (celdas) donde empieza la «U» por el oeste
# Aberturas de las elevaciones (círculos naranjas): x, y, radio en celdas.
ABERTURAS = [(210, 362, 34), (507, 330, 34), (880, 375, 48)]
TROZO = 128  # celdas por trozo de colisión


def capa(nombre):
    im = Image.open(CAPAS / f"{nombre}.png").convert("RGBA").resize((W, H), Image.BILINEAR)
    return np.array(im).astype(int)


def layout(nombre):
    im = Image.open(LAYOUTS / nombre).convert("RGB").resize((W, H), Image.BILINEAR)
    return np.array(im).astype(int)


def opaco(c):
    return c[..., 3] > 128


def verde(c):
    return opaco(c) & (c[..., 1] > c[..., 0] + 10)


def mascaras():
    piso, orilla = capa("piso"), capa("orilla")
    m1, m2 = capa("monte_1"), capa("monte_2")
    yy, xx = np.mgrid[0:H, 0:W]
    abert = np.zeros((H, W), bool)
    for cx, cy, r in ABERTURAS:
        abert |= (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
    mon_a, mon_v = opaco(m1) | opaco(m2), verde(m1) | verde(m2)
    ori_a = opaco(orilla)
    elev_u = verde(orilla) & (yy >= CIERRE)
    # Las briznas de hierba del dibujo partirían la pared en cientos de trocitos: la elevación
    # transitable es la mancha verde suavizada.
    elevado = ndi.binary_opening(ndi.binary_closing(elev_u | mon_v, iterations=4), iterations=4)
    suelo = opaco(piso) & ~ori_a & ~mon_a
    acantilado = ((ori_a & ~elev_u) | (mon_a & ~mon_v)) & ~elevado
    trans = (suelo | elevado) & ~(acantilado & ~abert)
    trans |= abert & (mon_a | opaco(piso)) & ~(ori_a & ~elev_u)
    trans = ndi.binary_opening(trans, iterations=1)
    # Pared de 2 celdas (4 px) alrededor de cada elevación, salvo en las aberturas.
    banda = ndi.binary_dilation(elevado, iterations=2) & ~elevado & ~abert
    trans &= ~banda
    trans[:2, :] = trans[-2:, :] = False
    trans[:, :2] = trans[:, -2:] = False
    lab, n = ndi.label(trans)
    tam = ndi.sum(trans, lab, range(1, n + 1))
    for i, v in enumerate(tam):
        if v < 200:
            trans[lab == i + 1] = False
    # Comprobación: sin las aberturas, cada elevación queda aislada del suelo.
    cerrado = trans & ~abert
    lab, n = ndi.label(cerrado)
    for i in range(1, n + 1):
        comp = lab == i
        if comp.sum() > 300:
            frac = (comp & elevado).sum() / comp.sum()
            assert frac in (0.0, 1.0) or frac < 0.001 or frac > 0.999, f"fuga entre suelo y elevación ({frac:.3f})"
    return trans, elevado, banda & ~elevado, suelo


def bosques(suelo, elevado):
    z = layout("Layout_nivel_2_zonas_rojas.jpeg")
    rojo = (z[..., 0] > 170) & (z[..., 1] < 70) & (z[..., 2] < 70)
    rojo = ndi.binary_closing(rojo, iterations=6)
    rojo = ndi.binary_fill_holes(rojo)
    rojo = ndi.binary_opening(rojo, iterations=2)
    rojo &= ~ndi.binary_dilation(elevado, iterations=6)
    lab, n = ndi.label(rojo)
    res = []
    for i in range(1, n + 1):
        comp = lab == i
        if comp.sum() < 2000:
            rojo[comp] = False
            continue
        res.append(comp)
    return rojo, res


def contorno(comp, tolerancia):
    """Polígono (px de mundo) del borde exterior de una mancha sin agujeros."""
    p = np.pad(comp, 1).astype(float)
    cs = measure.find_contours(p, 0.5)
    c = max(cs, key=len)
    c = measure.approximate_polygon(c, tolerance=tolerancia)
    pts = [[round(float((x - 1 + 0.5) * PX), 1), round(float((y - 1 + 0.5) * PX), 1)] for y, x in c[:-1]]
    return pts


def poligonos_solidos(solido, y0=0, x0=0, alto=None, ancho=None):
    """Polígonos simples de `solido` por trozos; si un trozo tiene agujeros, se parte."""
    alto = alto or solido.shape[0]
    ancho = ancho or solido.shape[1]
    res = []
    for ty in range(y0, y0 + alto, TROZO):
        for tx in range(x0, x0 + ancho, TROZO):
            res += _trozo(solido, ty, tx, min(TROZO, y0 + alto - ty), min(TROZO, x0 + ancho - tx))
    return res


def _trozo(solido, ty, tx, alto, ancho):
    sub = solido[ty:ty + alto, tx:tx + ancho]
    if not sub.any():
        return []
    lab, n = ndi.label(sub)
    res = []
    for i in range(1, n + 1):
        comp = lab == i
        if comp.sum() < 3:
            continue
        agujeros = ndi.binary_fill_holes(comp) & ~comp
        if agujeros.any():
            if alto <= 4 and ancho <= 4:
                comp = ndi.binary_fill_holes(comp)
            else:
                h2, w2 = max(alto // 2, 1), max(ancho // 2, 1)
                return (_trozo(solido, ty, tx, h2, w2) + _trozo(solido, ty, tx + w2, h2, ancho - w2)
                        + _trozo(solido, ty + h2, tx, alto - h2, w2)
                        + _trozo(solido, ty + h2, tx + w2, alto - h2, ancho - w2))
        pts = contorno(comp, 0.7)
        if len(pts) >= 3:
            res.append([[x + tx * PX, y + ty * PX] for x, y in pts])
    return res


def manchas(img, cond, minimo=20):
    lab, n = ndi.label(cond)
    res = []
    for i in range(1, n + 1):
        comp = lab == i
        if comp.sum() >= minimo:
            cy, cx = ndi.center_of_mass(comp)
            res.append((cx, cy))
    return res


def colocar(punto, libre, elevado, holgura, mantener_nivel=True):
    """Celda libre con `holgura` celdas a todo lo sólido más cercana a `punto` (celdas)."""
    cx, cy = int(round(punto[0])), int(round(punto[1]))
    dist = ndi.distance_transform_edt(libre)
    ok = dist >= holgura
    if mantener_nivel and libre[cy, cx]:
        ok &= elevado if elevado[cy, cx] else ~elevado
    yy, xx = np.nonzero(ok)
    k = np.argmin((xx - cx) ** 2 + (yy - cy) ** 2)
    return int(xx[k]), int(yy[k]), float(dist[yy[k], xx[k]])


def mundo(c):
    return [round((c[0] + 0.5) * PX), round((c[1] + 0.5) * PX)]


def main():
    trans, elevado, banda, suelo = mascaras()
    rojo, comps = bosques(suelo, elevado)
    libre = trans & ~rojo
    datos = {
        "tamano": [round(LIENZO[0] * ESCALA_MAPA), round(LIENZO[1] * ESCALA_MAPA)],
        "escala_mapa": ESCALA_MAPA,
        "aberturas": [mundo((x, y)) + [r * PX] for x, y, r in ABERTURAS],
    }
    costa = ~trans & ~banda
    datos["costa"] = poligonos_solidos(costa)
    datos["bordes_elevacion"] = poligonos_solidos(banda & ~trans)
    datos["bosques"] = [contorno(c, 3.0) for c in comps]

    az = layout("Layout_nivel_2_puntos_azules.jpeg")
    azules = manchas(az, (az[..., 2] > 200) & (az[..., 0] < 80) & (az[..., 1] < 120))
    am = layout("Layout_nivel_2_puntos_amarillos.jpeg")
    amarillos = manchas(am, (am[..., 0] > 230) & (am[..., 1] > 220) & (am[..., 2] < 90))
    enemigos = []
    for p in sorted(azules, key=lambda q: (q[1], q[0])):
        x, y, d = colocar(p, libre, elevado, 8)
        enemigos.append({"pos": mundo((x, y)), "holgura": round(d * PX), "elevado": bool(elevado[y, x]),
                         "movido": round(float(np.hypot(x - p[0], y - p[1]) * PX))})
    datos["enemigos"] = enemigos
    cofres = []
    for p in sorted(amarillos, key=lambda q: (q[1], q[0])):
        x, y, d = colocar(p, libre, elevado, 10)
        cofres.append({"pos": mundo((x, y)), "elevado": bool(elevado[y, x]),
                       "movido": round(float(np.hypot(x - p[0], y - p[1]) * PX))})
    datos["cofres"] = cofres
    SALIDA.write_text(json.dumps(datos, indent=1))
    print(f"costa {len(datos['costa'])} polígonos, bordes {len(datos['bordes_elevacion'])}, "
          f"bosques {len(datos['bosques'])}, enemigos {len(enemigos)}, cofres {len(cofres)}")
    if "--vista" in sys.argv:
        img = np.zeros((H, W, 3), np.uint8)
        img[trans] = (200, 190, 120)
        img[trans & elevado] = (80, 200, 80)
        img[rojo] = (200, 30, 30)
        Image.fromarray(img).save("/tmp/isla_vista.png")


if __name__ == "__main__":
    main()
