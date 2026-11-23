"""Saca la colisión del pasillo de Medusa (cueva_medusa) de la máscara de la diseñadora.

  python3 -I tools/zonas/pasillo/calcular_colision.py [vista_previa.png]

Entrada (2026-11-23, mandada por la diseñadora para ampliar la zona previa a Medusa):
  docs/reference/nivel2/pasillo/limite_de_pasillo.png
      2786×1080 RGBA, el lienzo del fondo píxel a píxel: lo NEGRO (alfa) no se pisa. Tiene la forma
      de los pilares, de las rocas de los bordes y del muro de arriba; el resto es suelo. Sustituye a
      los dos trazos rojos de la versión anterior (disenadora_inferior/superior.png), que dejaban
      un pasillo serpenteante muy estrecho: así «no se pierde el espacio».
Además de la máscara se suma la silueta de cada Decorado del pasillo (cristales, estatuas y rocas
del sur): la máscara no lleva las estatuas de arriba (la diseñadora pidió antes que no se
atraviesen) y se queda corta en la punta de dos cristales y en un trozo de roca del sur.
Salida: tools/zonas/pasillo/colision_pasillo.json (polígonos en px de mundo, escala 0,4) y las
posiciones de los enemigos. `aplicar_colision.py` lo pasa a la escena.
"""
import json, re, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure

RAIZ = "docs/reference/nivel2/pasillo/"
ESCENA = "scenes/levels/cueva_medusa.tscn"
S = 0.4                     # px de mundo por px del lienzo del fondo
PAD = 60                    # px de lienzo que los bloqueos se prolongan fuera del dibujo
TOLERANCIA = 2.0            # px de lienzo al simplificar los contornos (0,8 px de mundo)
MARGEN_OBJETOS = 6          # px de lienzo (~2,4 de mundo) que se ensancha la silueta de cada objeto
HOLGURA = 24.0              # holgura mínima (px de mundo) alrededor de un enemigo
ENTRADA_IZQ, ENTRADA_DER = (50, 215), (1064, 215)   # desde_isla / desde_jefe

limite = np.asarray(Image.open(RAIZ + "limite_de_pasillo.png"))[..., 3].astype(float) / 255
H, W = limite.shape

# Siluetas de los Decorados del pasillo (PasilloCristal*, PasilloEstatua*, PasilloRocas* de la escena,
# a escala 0,4 = 1 px de lienzo).
t = open(ESCENA).read()
rutas = {i: r for r, i in re.findall(r'\[ext_resource type="Texture2D"[^\]]*path="res://([^"]+)" id="([^"]+)"', t)}
objetos = np.zeros((H, W), bool)
fuera = {}
for m in re.finditer(r'\[node name="(Pasillo\w+)" parent="Objetos/Ruinas"[^\n]*\n((?:[^\n\[][^\n]*\n)*)', t):
    nombre, b = m.groups()
    x, y = map(float, re.search(r"position = Vector2\(([\d.]+), ([\d.]+)\)", b).groups())
    alfa = np.asarray(Image.open(rutas[re.search(r'textura = ExtResource\("([^"]+)"\)', b).group(1)]).convert("RGBA"))[..., 3] > 90
    h, w = alfa.shape
    x0, y0 = int(round(x / S - w / 2)), int(round(y / S - h))
    sil = np.zeros((H, W), bool)
    xs, xe, ys, ye = max(x0, 0), min(x0 + w, W), max(y0, 0), min(y0 + h, H)
    sil[ys:ye, xs:xe] = alfa[ys - y0:ye - y0, xs - x0:xe - x0]
    objetos |= ndi.binary_dilation(ndi.binary_closing(sil, iterations=2), iterations=MARGEN_OBJETOS)
    fuera[nombre] = int((sil & (limite < 0.5)).sum())
print("píxeles dibujados que la máscara deja libres (se suman):", fuera)

bloqueado = np.maximum(limite, objetos.astype(float))
# Fuera del dibujo: los lados siguen como están en el borde (las salidas laterales quedan libres), por
# arriba y por abajo todo es pared (el suelo llega al borde inferior de la imagen: debajo no hay nada).
m = np.pad(bloqueado, ((0, 0), (PAD, PAD)), mode="edge")
m = np.pad(m, ((PAD, PAD), (0, 0)), mode="constant", constant_values=1.0)
m = np.pad(m, 1)                       # anillo vacío: los contornos se cierran fuera
poligonos = []
for c in measure.find_contours(m, 0.5):
    c = measure.approximate_polygon(c, TOLERANCIA)
    if len(c) < 4:
        continue
    pts = [[round((x - 1 - PAD) * S, 1), round((y - 1 - PAD) * S, 1)] for y, x in c[:-1]]
    area = abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2
    # ojo: un contorno puede ser el de un agujero de suelo libre rodeado de pared (no debería haber)
    cx, cy = np.mean(pts, axis=0)
    print("  contorno de %d vértices, área %d px², hacia (%d, %d)%s" % (len(pts), area, cx, cy, "" if area > 100 else " -> se descarta"))
    if area > 100:
        poligonos.append(pts)
res = {"poligonos": poligonos}

libre = bloqueado < 0.5
lab, _ = ndi.label(libre)
a, b = lab[int(ENTRADA_IZQ[1] / S), int(ENTRADA_IZQ[0] / S)], lab[int(ENTRADA_DER[1] / S), int(ENTRADA_DER[0] / S)]
print("izquierda y derecha conectadas:", a == b and a > 0)

# Enemigos: las posiciones del plan original (270,215) (470,130) (700,150) (780,300), con las gambas
# en (640,300); si caen en suelo sin holgura se acercan al suelo libre más próximo.
CICLOPES = [(270, 215), (470, 130), (700, 150), (780, 300)]
GAMBAS = [(654, 300), (626, 312), (642, 288), (668, 316)]   # grupo de 4, 24 px de lado
dt = ndi.distance_transform_edt(libre) * S
ys, xs = np.nonzero(dt >= HOLGURA)


def cercano(x, y):
    d = (xs * S - x) ** 2 + (ys * S - y) ** 2
    i = int(np.argmin(d))
    return [round(xs[i] * S), round(ys[i] * S)]


res["ciclopes"] = [cercano(x, y) for x, y in CICLOPES]
cx = sum(p[0] for p in GAMBAS) / 4
cy = sum(p[1] for p in GAMBAS) / 4
nx, ny = cercano(cx, cy)
res["gambas"] = [[round(x + nx - cx), round(y + ny - cy)] for x, y in GAMBAS]
print("cíclopes", res["ciclopes"])
print("gambas", res["gambas"], "(centro del grupo", [nx, ny], ")")
json.dump(res, open("tools/zonas/pasillo/colision_pasillo.json", "w"))

# Holgura del paso más estrecho entre las dos entradas.
mejor = 0
for r in range(1, 80):
    lab2, _ = ndi.label(dt >= r)
    a2, b2 = lab2[int(ENTRADA_IZQ[1] / S), int(ENTRADA_IZQ[0] / S)], lab2[int(ENTRADA_DER[1] / S), int(ENTRADA_DER[0] / S)]
    if a2 > 0 and a2 == b2:
        mejor = r
    else:
        break
print("paso más estrecho: %d px de ancho libre" % (mejor * 2))

# Vista previa sobre el pasillo terminado: en rojo lo que no se pisa.
base = np.array(Image.open(RAIZ + "pasillo_nuevo.jpg").convert("RGB").resize((W // 2, H // 2)))
bl = np.array(Image.fromarray((bloqueado * 255).astype("uint8")).resize((W // 2, H // 2))) > 127
base[bl] = (base[bl] * 0.45 + np.array([255, 0, 0]) * 0.55).astype("uint8")
Image.fromarray(base).save(sys.argv[1] if len(sys.argv) > 1 else "/tmp/vista_colision.png")
