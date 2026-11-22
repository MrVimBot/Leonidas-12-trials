"""Colisión de las 4 estatuas rotas de la sala del jefe (cueva_jefe) con la silueta del dibujo.

  python3 -I tools/zonas/medusa/colision_estatuas_arena.py     # con el editor cerrado

El Decorado solo trae un rectángulo en la base: Leonidas atravesaba el cuerpo de la estatua
menos esa pieza. Aquí cada estatua pasa a `solido = false` (sin su rectángulo) y lleva hijos
CollisionPolygon2D (`Cuerpo1`, …) con el contorno de cada mancha grande del PNG (el polvo y los
trocitos sueltos no cuentan). Coordenadas relativas a la estatua: el origen es el centro de
abajo del PNG, a escala 0,11. Repetible.
"""
import re
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure

ESCALA = 0.11
RUTA = "scenes/levels/cueva_jefe.tscn"
ESTATUAS = {"Estatua1": 1, "Estatua2": 2, "Estatua3": 3, "Estatua4": 4}


def contornos(n):
    img = Image.open("assets/sprites/entorno/nivel2/medusa_estatua_%d.png" % n).convert("RGBA")
    w, h = img.size
    alfa = np.array(img)[..., 3] > 90
    alfa = ndi.binary_dilation(ndi.binary_closing(alfa, iterations=3), iterations=12)  # ~1,3 px de mundo de margen
    lab, k = ndi.label(alfa)
    areas = ndi.sum(alfa, lab, range(1, k + 1))
    out = []
    for i, a in enumerate(areas, 1):
        if a < 0.012 * areas.max():
            continue
        m = np.pad(ndi.binary_fill_holes(lab == i), 1)
        for c in measure.find_contours(m.astype(float), 0.5):
            c = measure.approximate_polygon(c, 6.0)
            if len(c) < 4:
                continue
            pts = [(round((x - 1 - w / 2) * ESCALA, 1), round((y - 1 - h) * ESCALA, 1)) for y, x in c[:-1]]
            area = abs(sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(pts, pts[1:] + pts[:1]))) / 2
            if area > 4:
                out.append(pts)
    return out


s = open(RUTA).read()
for nodo, n in ESTATUAS.items():
    # fuera los cuerpos anteriores de esta estatua
    s = re.sub(r'\[node name="Cuerpo\d+" type="CollisionPolygon2D" parent="Objetos/Petrificados/%s"\]\n(?:[^\n\[][^\n]*\n)*\n?' % nodo, "", s)
    hijos = ""
    for i, pts in enumerate(contornos(n), 1):
        hijos += '[node name="Cuerpo%d" type="CollisionPolygon2D" parent="Objetos/Petrificados/%s"]\npolygon = PackedVector2Array(%s)\n\n' % (
            i, nodo, ", ".join("%s, %s" % p for p in pts))
    patron = r'(\[node name="%s" parent="Objetos/Petrificados"[^\n]*\n(?:[^\n\[][^\n]*\n)*)\n' % nodo
    m = re.search(patron, s)
    bloque = m.group(1)
    if "solido = false" not in bloque:
        bloque += "solido = false\n"
    s = s[:m.start()] + bloque + "\n" + hijos + s[m.end():]
    print(nodo, "->", hijos.count("CollisionPolygon2D"), "polígono(s)")
open(RUTA, "w").write(s)
