"""Saca la colisión del pasillo de Medusa (cueva_medusa) de los dos trazos rojos de la diseñadora.

  python3 -I tools/zonas/pasillo/calcular_colision.py

Entradas (capturas de Telegram con el «Resultado de pasillo de medusa» y su trazo rojo):
  docs/reference/nivel2/pasillo/disenadora_inferior.png  -> lo de DEBAJO de la línea es intransitable
                                                          (los pilares de abajo: Leonidas va por detrás)
  docs/reference/nivel2/pasillo/disenadora_superior.png  -> lo ENCERRADO por la curva es intransitable
                                                          (los pilares y estatuas de arriba)
Salida: tools/zonas/pasillo/colision_pasillo.json (polígonos en px de mundo, escala 0,4).

Los dos trazos se cruzan en el centro (entre los pilares 2 y 3 no queda paso): se abre una
garganta de `ANCHO_PASO` px por el camino que menos invade lo dibujado (Dijkstra).
Posición de la imagen dentro de cada captura: medida comparando con el «Resultado».
"""
import json, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import graph, measure

RAIZ = "docs/reference/nivel2/pasillo/"
W, H = 550, 213                       # el «Resultado» (2786×1080) dentro de la captura
S = 0.4 / (W / 2786)                  # px de captura -> px de mundo
ANCHO_PASO = 56.0                     # ancho mínimo de la garganta (px de mundo)
ENSANCHAR = 16.0                      # cuánto se retraen los trazos de la diseñadora (px de mundo): el pasillo
                                      # salía muy angosto; las siluetas de los pilares no se tocan
MUNDO = (1114, 432)


def region(archivo, x0, y0, idx):
    im = np.array(Image.open(RAIZ + archivo).convert("RGB")).astype(int)
    rojo = ((im[..., 0] > 170) & (im[..., 1] < 120) & (im[..., 2] < 120))[y0:y0 + H, x0:x0 + W]
    rojo = ndi.binary_dilation(rojo, iterations=1)
    lab, _ = ndi.label(~rojo)
    return (lab == idx) | rojo


inferior = region("disenadora_inferior.png", 7, 36, 2)   # debajo de la línea
superior = region("disenadora_superior.png", 11, 36, 2)  # encerrado por la curva
# Se retraen los trazos (pegados al borde de la imagen no: ahí no hay trazo) para ensanchar el suelo.
_n = int(round(ENSANCHAR / S))
inferior = ndi.binary_erosion(inferior, iterations=_n, border_value=1)
superior = ndi.binary_erosion(superior, iterations=_n, border_value=1)
# Muro de arriba del dibujo (y < 56) y rocas de los extremos, en px de mundo.
muro = int(56 / S)
superior[:muro, :] = True
xi, xd = int((130 + ENSANCHAR) / S), int((1000 - ENSANCHAR) / S)
yr = int(150 / S)
superior[:yr, :xi] = True
superior[:yr, xd:] = True
superior = ndi.binary_closing(np.pad(superior, 4, mode="edge"), iterations=3)[4:-4, 4:-4]   # sin rendijas sueltas

# Siluetas de lo dibujado en pilares, estatuas y rocas (~4 px de mundo de margen): nunca quedan libres.
PIEZAS = [  # nombre, x0, x1, y0, y1 (en el «Resultado» de 2786×1080), grupo
    ("pasillo_cristal_1", 284, 740, 0, 682, "superior"), ("pasillo_cristal_2", 1305, 1755, 6, 639, "superior"),
    ("pasillo_cristal_3", 2202, 2498, 16, 462, "superior"), ("pasillo_estatua_1", 681, 961, 15, 380, "superior"),
    ("pasillo_estatua_2", 2122, 2317, 1, 479, "superior"), ("pasillo_rocas_1", 856, 1301, 457, 1079, "inferior"),
    ("pasillo_rocas_2", 1762, 2305, 613, 1079, "inferior"), ("pasillo_rocas_3", 0, 297, 844, 1079, "inferior"),
    ("pasillo_rocas_4", 2551, 2786, 845, 1079, "inferior")]
K = W / 2786
sil_inf = np.zeros((H, W), bool)
sil_sup = np.zeros((H, W), bool)
for nombre, x0, x1, y0, y1, grupo in PIEZAS:
    alfa = np.array(Image.open("assets/sprites/entorno/nivel2/%s.png" % nombre).split()[-1]) > 90
    sil = np.zeros((H, W), bool)
    ys, xs = np.nonzero(alfa)
    sil[np.clip(((ys + y0) * K).astype(int), 0, H - 1), np.clip(((xs + x0) * K).astype(int), 0, W - 1)] = True
    sil = ndi.binary_dilation(ndi.binary_closing(sil, iterations=2), iterations=2)
    if grupo == "inferior":
        sil_inf |= sil
    else:
        sil_sup |= sil

# Garganta: ruta de menor invasión entre las dos salidas (lo dibujado cuesta mucho más que un
# trazo de la diseñadora, que se puede ensanchar).
lineas = inferior | superior
silueta = sil_inf | sil_sup
d0 = ndi.distance_transform_edt(~(lineas | silueta)) * S           # holgura de cada punto
# Cuesta más lo que está dentro de un trazo, muchísimo más lo dibujado, y algo lo que roza una pared
# (así la ruta va por el centro y solo ensancha donde de verdad no cabe).
coste = np.where(silueta, 500.0, np.where(lineas, 40.0, 1.0 + 6.0 * np.clip((ANCHO_PASO / 2 - d0) / (ANCHO_PASO / 2), 0, 1)))
ruta, _ = graph.route_through_array(coste, (int(215 / S), int(50 / S)), (int(215 / S), int(1064 / S)), fully_connected=True, geometric=True)
ruta = np.array(ruta)
camino = np.zeros_like(lineas)
# Solo se abre donde la ruta no tiene holgura para el jugador (< 12 px): la garganta. El resto de
# los trazos de la diseñadora se respeta tal cual.
justo = d0[ruta[:, 0], ruta[:, 1]] < 12.0
camino[ruta[justo, 0], ruta[justo, 1]] = True
abrir = ndi.distance_transform_edt(~camino) * S <= ANCHO_PASO / 2
inferior = (inferior & ~abrir) | sil_inf
superior = (superior & ~abrir) | sil_sup
print("garganta abierta:", int((abrir & lineas).sum()), "px de captura")


def poligonos(mascara, relleno):
    """Contornos de la máscara (con `relleno` = lados que siguen fuera del dibujo)."""
    pad = 12
    m = np.pad(mascara, pad, mode="edge")
    m = np.pad(m, 1)                      # anillo vacío: así los contornos se cierran fuera del dibujo
    m = ndi.binary_fill_holes(m)
    pad += 1
    out = []
    for c in measure.find_contours(m.astype(float), 0.5):
        c = measure.approximate_polygon(c, 1.2)
        if len(c) < 4:
            continue
        pts = [[round((x - pad) * S, 1), round((y - pad) * S, 1)] for y, x in c[:-1]]
        area = abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2
        print("  polígono", len(pts), "vértices, área", round(area))
        if area > 200:
            out.append(pts)
    return out


res = {"inferior": poligonos(inferior, "abajo"), "superior": poligonos(superior, "arriba")}
json.dump(res, open("tools/zonas/pasillo/colision_pasillo.json", "w"))
for k, v in res.items():
    print(k, [len(p) for p in v])
libre = ~(inferior | superior)
lab, _ = ndi.label(libre)
a, b = lab[int(215 / S), int(50 / S)], lab[int(215 / S), int(1064 / S)]
print("izquierda y derecha conectadas:", a == b and a > 0)

# Vista previa sobre el «Resultado».
base = Image.open("/Users/mrrobote05/Downloads/PASILLO DE MEDUSA/Resultado de pasillo de medusa.png").convert("RGB").resize((W, H))
arr = np.array(base)
arr[inferior] = (arr[inferior] * 0.4 + np.array([255, 0, 0]) * 0.6).astype("uint8")
arr[superior] = (arr[superior] * 0.4 + np.array([0, 80, 255]) * 0.6).astype("uint8")
Image.fromarray(arr).resize((W * 2, H * 2)).save(sys.argv[1] if len(sys.argv) > 1 else "/tmp/vista_colision.png")

# Enemigos: se conservan sus posiciones y solo se acercan al suelo libre más próximo si quedaron
# dentro de lo intransitable (holgura mínima `HOLGURA` px de mundo para que quepan).
HOLGURA = 24.0
# Posiciones del plan original (270,215) (470,130) (700,150) (780,300) y gambas en (640,300),
# repartidas por las cámaras del pasillo ahora que el suelo es serpenteante.
CICLOPES = [(230, 335), (395, 215), (800, 225), (930, 310)]
GAMBAS = [(674, 368), (646, 382), (632, 360), (662, 350)]
dt = ndi.distance_transform_edt(libre) * S
validos = dt >= HOLGURA
ys, xs = np.nonzero(validos)


def cercano(x, y):
    d = (xs * S - x) ** 2 + (ys * S - y) ** 2
    i = int(np.argmin(d))
    return [round(xs[i] * S), round(ys[i] * S)]


ciclopes = [cercano(x, y) for x, y in CICLOPES]
cx = sum(p[0] for p in GAMBAS) / 4
cy = sum(p[1] for p in GAMBAS) / 4
nx, ny = cercano(cx, cy)
gambas = [[round(x + nx - cx), round(y + ny - cy)] for x, y in GAMBAS]
res["ciclopes"] = ciclopes
res["gambas"] = gambas
json.dump(res, open("tools/zonas/pasillo/colision_pasillo.json", "w"))
print("cíclopes", ciclopes)
print("gambas", gambas, "(centro del grupo", [nx, ny], ")")

# Holgura del paso más estrecho: el mayor radio r tal que sigue habiendo camino con r px a cada lado.
dtl = ndi.distance_transform_edt(libre) * S
mejor = 0
for r in range(1, 40):
    lab2, _ = ndi.label(dtl >= r)
    a2, b2 = lab2[int(215 / S), int(50 / S)], lab2[int(215 / S), int(1064 / S)]
    if a2 > 0 and a2 == b2:
        mejor = r
    else:
        break
print("paso más estrecho: %d px de ancho libre" % (mejor * 2))

# Penumbra: oscurece lo que no se puede pisar (degradado suave de ~8 px) para que el camino se
# lea de un vistazo. PNG a mitad de resolución del mundo (2 px de mundo por píxel), alfa máximo
# OSCURO; va como Sprite2D `Penumbra` encima del fondo y debajo de los objetos.
OSCURO = 0.62
suave = ndi.gaussian_filter(libre.astype(float), sigma=4.0 / S)
alfa = np.clip(1.0 - suave * 1.15, 0, 1) * OSCURO          # el camino queda del todo limpio
img = Image.fromarray((alfa * 255).astype("uint8")).resize((MUNDO[0] // 2, MUNDO[1] // 2), Image.BICUBIC)
sal = Image.new("RGBA", img.size, (8, 4, 20, 0))
sal.putalpha(img)
sal.save("assets/backgrounds/nivel2/pasillo_medusa/penumbra.png")
print("penumbra.png", sal.size)

if "--debug" in sys.argv:
    for xw in (470, 490, 500, 510, 520, 540):
        col = libre[:, int(xw / S)]
        ys = np.nonzero(col)[0]
        trozos = np.split(ys, np.nonzero(np.diff(ys) > 1)[0] + 1)
        print("x", xw, [(round(t[0] * S), round(t[-1] * S)) for t in trozos if len(t)])
