"""Colocación y colisión de las 4 estatuas rotas de la sala del jefe (cueva_jefe).

  python3 -I tools/zonas/medusa/colision_estatuas_arena.py     # con el editor cerrado

**Colocación** (2026-11-23): la diseñadora entregó la sala como debe verse
(`docs/reference/nivel2/arena_medusa_como_se_debe_ver.jpg`). Restando el fondo sin estatuas se ve
dónde va cada una: los PNG están a **escala 1** sobre el lienzo de 1920×1080 del fondo (por eso,
a escala 0,3 como él, miden ~85–145 px de mundo; antes se pusieron a 0,11 por error y salían
minúsculas). `ESQUINA` es la esquina superior izquierda de cada PNG en ese lienzo (medida por
correlación con la diferencia imagen − fondo, IoU 0,86–0,94). Cada estatua lleva un `ancla` en
sus pies (px de textura) para que el orden por Y con Leonidas sea el de sus pies.

**Colisión:** el Decorado solo trae un rectángulo en la base: Leonidas atravesaba el cuerpo de
la estatua menos esa pieza. Aquí cada estatua pasa a `solido = false` (sin su rectángulo) y lleva
hijos CollisionPolygon2D (`Cuerpo1`, …) con el contorno de cada mancha grande del PNG. No cuentan
el polvo, los trocitos sueltos ni lo que está tirado en el suelo (la lanza, el casco roto, los
escombros: `RECORTE` los quita). Coordenadas relativas al ancla de la estatua. Repetible.
"""
import re
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure

ESCALA = 0.3  # la del fondo de la sala (Mapa/Fondo): el arte de la diseñadora está a escala 1 sobre su lienzo
FONDO_POS = (-17.5, 25.0)  # posición del fondo en el mundo (cueva_jefe: Mapa/Fondo)
RUTA = "scenes/levels/cueva_jefe.tscn"
ESTATUAS = {"Estatua1": 1, "Estatua2": 2, "Estatua3": 3, "Estatua4": 4}
# Esquina superior izquierda de cada PNG sobre el lienzo de 1920×1080 (medida, ver arriba).
ESQUINA = {1: (550, 0), 2: (1030, 671), 3: (1177, 171), 4: (169, 462)}
# Punto de los pies (px de textura): ahí se ordena por Y con Leonidas y ahí está el origen de
# la colisión. Cuerpo principal, sin el margen de la dilatación (medido en cada PNG).
ANCLA = {1: (139, 330), 2: (213, 368), 3: (302, 430), 4: (297, 327)}
# Zonas del PNG que NO bloquean (px de textura, x0, y0, x1, y1): lo tirado en el suelo.
RECORTE = {3: [(0, 255, 255, 375)]}  # escombros del lobo, pegados a su pie izquierdo
# Solo cuentan las manchas de al menos esta parte de la mayor: la lanza (12 %), el casco roto
# del lobo (10 %) y la pieza suelta de la estatua 2 (8 %) quedan en el suelo, sin colisión.
AREA_MINIMA = 0.15
MARGEN = 6  # px de textura que se ensancha la silueta (≈ 1,8 px de mundo)


def contornos(n):
    img = Image.open("assets/sprites/entorno/nivel2/medusa_estatua_%d.png" % n).convert("RGBA")
    w, h = img.size
    alfa = np.array(img)[..., 3] > 90
    # el polvo y los trocitos sueltos no cuentan, y tampoco lo que está tirado en el suelo
    lab, k = ndi.label(alfa)
    areas = ndi.sum(alfa, lab, range(1, k + 1))
    alfa = np.isin(lab, [i for i in range(1, k + 1) if areas[i - 1] >= 1500])
    for x0, y0, x1, y1 in RECORTE.get(n, []):
        alfa[y0:y1, x0:x1] = False
    alfa = ndi.binary_dilation(ndi.binary_closing(alfa, iterations=3), iterations=MARGEN)
    lab, k = ndi.label(alfa)
    areas = ndi.sum(alfa, lab, range(1, k + 1))
    ax, ay = ANCLA[n]
    out = []
    for i, a in enumerate(areas, 1):
        if a < AREA_MINIMA * areas.max():
            continue
        m = np.pad(ndi.binary_fill_holes(lab == i), 1)
        for c in measure.find_contours(m.astype(float), 0.5):
            c = measure.approximate_polygon(c, 6.0)
            if len(c) < 4:
                continue
            pts = [(round((x - 1 - ax) * ESCALA, 1), round((y - 1 - ay) * ESCALA, 1)) for y, x in c[:-1]]
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
    ex, ey = ESQUINA[n]
    ax, ay = ANCLA[n]
    pos = "position = Vector2(%s, %s)" % (round(FONDO_POS[0] + (ex + ax) * ESCALA, 1), round(FONDO_POS[1] + (ey + ay) * ESCALA, 1))
    bloque = re.sub(r"position = Vector2\([^\n]*\)", pos, bloque)
    bloque = re.sub(r"escala = [\d.]+", "escala = %s" % ESCALA, bloque)
    bloque = re.sub(r"ancla = Vector2\([^\n]*\)\n", "", bloque)
    bloque = bloque.replace("escala = %s\n" % ESCALA, "escala = %s\nancla = Vector2(%d, %d)\n" % (ESCALA, ax, ay))
    if "solido = false" not in bloque:
        bloque += "solido = false\n"
    s = s[:m.start()] + bloque + "\n" + hijos + s[m.end():]
    print(nodo, "->", hijos.count("CollisionPolygon2D"), "polígono(s)")
open(RUTA, "w").write(s)
