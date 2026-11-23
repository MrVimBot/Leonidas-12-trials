"""Pone en scenes/levels/cueva_medusa.tscn la colisión y los enemigos de colision_pasillo.json.

  python3 -I tools/zonas/pasillo/calcular_colision.py     # máscara de la diseñadora -> json
  python3 -I tools/zonas/pasillo/aplicar_colision.py      # json -> escena (con el editor cerrado)

Edita el texto de la escena (no hay que abrir Godot): sustituye los nodos Borde*/Inferior*/Superior*/
Muro* de `Limites` y las posiciones de los cíclopes y las gambas, y quita la penumbra y el
oscurecido de los objetos de la versión anterior (la sombra ahora va en el fondo: ver
actualizar_fondo.py). Es repetible.
"""
import json, re

d = json.load(open("tools/zonas/pasillo/colision_pasillo.json"))
p = "scenes/levels/cueva_medusa.tscn"
s = open(p).read()


def area2(pts):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))


def cruz(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def convexo(pts):
    n = len(pts)
    return all(cruz(pts[i], pts[(i + 1) % n], pts[(i + 2) % n]) >= -1e-9 for i in range(n))


def triangular(pts):
    """Recorte de orejas de un polígono simple (sentido antihorario en cruz())."""
    pts = [tuple(p) for p in pts]
    if area2(pts) < 0:
        pts.reverse()
    idx = list(range(len(pts)))
    out = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if cruz(a, b, c) <= 1e-9:
                continue
            if any(j not in (i0, i1, i2) and cruz(a, b, pts[j]) >= 0 and cruz(b, c, pts[j]) >= 0 and cruz(c, a, pts[j]) >= 0 for j in idx):
                continue
            out.append([a, b, c])
            idx.pop(k)
            break
        else:
            break  # polígono degenerado: se deja lo que haya
    if len(idx) == 3:
        out.append([pts[i] for i in idx])
    return out


def unir(piezas):
    """Hertel-Mehlhorn: junta triángulos vecinos mientras el resultado siga siendo convexo."""
    cambio = True
    while cambio:
        cambio = False
        for i in range(len(piezas)):
            for j in range(i + 1, len(piezas)):
                A, B = piezas[i], piezas[j]
                for ia in range(len(A)):
                    a, b = A[ia], A[(ia + 1) % len(A)]
                    ib = next((k for k in range(len(B)) if B[k] == b and B[(k + 1) % len(B)] == a), None)
                    if ib is None:
                        continue
                    nuevo = A[ia + 1:] + A[:ia + 1]            # empieza en b ... termina en a
                    nuevo = nuevo[:-1] + B[ib + 2:] + B[:ib]    # sin repetir a ni b
                    nuevo = [b] + A[ia + 2:] + A[:ia] if False else None
                    # reconstrucción clara: recorrer A desde b hasta a y B desde a hasta b
                    ra = [A[(ia + 1 + t) % len(A)] for t in range(len(A))]        # b ... a
                    rb = [B[(ib + 1 + t) % len(B)] for t in range(len(B))]        # a ... b
                    poli = ra + rb[1:-1]
                    if convexo(poli):
                        piezas[i] = poli
                        del piezas[j]
                        cambio = True
                        break
                if cambio:
                    break
            if cambio:
                break
    return piezas


def convexos(pts):
    return unir(triangular(pts))


def poligono(nombre, pts):
    return '[node name="%s" type="CollisionPolygon2D" parent="Limites"]\npolygon = PackedVector2Array(%s)\n\n' % (
        nombre, ", ".join("%s, %s" % (x, y) for x, y in pts))


nuevo = ""
# Cada contorno se parte aquí en piezas convexas: la descomposición automática de Godot daba
# piezas que invadían el suelo libre (el pasillo parecía más estrecho de lo que es).
for i, pts in enumerate(d["poligonos"], 1):
    for k, pieza in enumerate(convexos(pts), 1):
        nuevo += poligono("Borde%d_%d" % (i, k), pieza)
# Muros fuera de las salidas laterales (el jugador sale por las Area2D antes de llegar).
for nombre, (x0, x1) in (("MuroOeste", (-40, -12)), ("MuroEste", (1126, 1154))):
    nuevo += poligono(nombre, [(x0, -40), (x1, -40), (x1, 480), (x0, 480)])
# Quita los anteriores (Borde, Inferior*, Superior*, Muro*) y pone los nuevos tras `Limites`.
s = re.sub(r'\[node name="(Borde[\d_]*|Inferior[\d_]+|Superior[\d_]+|Muro\w+)" type="CollisionPolygon2D" parent="Limites"[^\]\n]*\]\n(?:[^\n\[][^\n]*\n)*\n?', "", s)  # [^\]]*: el editor añade unique_id=…
s = re.sub(r'(\[node name="Limites" type="StaticBody2D"[^\n]*\n(?:[^\n\[][^\n]*\n)*\n)', lambda m: m.group(1) + nuevo, s, count=1)
for i, pos in enumerate(d["ciclopes"], 1):
    s = re.sub(r'(\[node name="CiclopeSerpiente%d"[^\n]*\n)position = Vector2\([^)]*\)' % i, r"\1position = Vector2(%d, %d)" % tuple(pos), s)
for i, pos in enumerate(d["gambas"], 1):
    s = re.sub(r'(\[node name="Gamba%d"[^\n]*\n)position = Vector2\([^)]*\)' % i, r"\1position = Vector2(%d, %d)" % tuple(pos), s)

# Limpieza de la versión anterior: la penumbra (Mapa/Penumbra + su textura) y los objetos atenuados
# (modulate) se quitaron al llegar el arte con la sombra de la diseñadora.
s = re.sub(r'\[ext_resource [^\n]*id="40_penumbra"\]\n', "", s)
s = re.sub(r'\[node name="Penumbra" type="Sprite2D" parent="Mapa"[^\n]*\n(?:[^\n\[][^\n]*\n)*\n?', "", s)
s = s.replace("modulate = Color(0.56, 0.5, 0.66, 1)\n", "")
open(p, "w").write(s)
print("escena actualizada")
