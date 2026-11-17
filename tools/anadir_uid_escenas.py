#!/usr/bin/env python3
"""Añade `uid="uid://..."` a las líneas [ext_resource ...] de las escenas que no lo traen.

Para qué sirve: las escenas escritas a mano o guardadas por los constructores en modo
consola (tools/build_zonas.gd, build_pueblo.gd...) referencian los recursos solo por ruta;
sin UID, mover o renombrar un archivo rompe la referencia. Este script es un parche de
TEXTO mínimo: solo inserta ` uid="uid://..."` entre `type` y `path` y no toca nada más
(ids, orden, saltos de línea, final de archivo).

De dónde saca el UID del destino (nunca inventa uno):
  - .gd / .gdshader        -> archivo hermano `X.uid`
  - recursos importados    -> línea `uid="..."` de `X.import`
  - .tscn / .tres          -> `uid=` de su cabecera ([gd_scene ...] / [gd_resource ...])
Si el destino no tiene UID conocido, la línea se deja igual y se lista (los .tscn/.tres
sin uid en la cabecera solo los puede generar Godot al guardarlos desde el editor).

Cuándo usarlo: tras regenerar zonas con los constructores. Con el editor cerrado o sin
tocar esas escenas a la vez.

Uso (desde la raíz del proyecto):
    python3 tools/anadir_uid_escenas.py            # simulación: solo informa
    python3 tools/anadir_uid_escenas.py --aplicar  # escribe los cambios
"""
import re, sys, glob, os

APLICAR = "--aplicar" in sys.argv
RAIZ = os.getcwd()
UID_RE = re.compile(r'^uid://[a-z0-9]+$')
EXT_RE = re.compile(r'^(\[ext_resource type="[^"]*") (path="res://([^"]+)".*)$')
CAB_RE = re.compile(r'^\[(?:gd_scene|gd_resource)\b[^\]]*?\buid="([^"]+)"')


def leer(ruta):
    with open(ruta, "r", encoding="utf-8", newline="") as f:
        return f.read()


def uid_de(rel):
    ruta = os.path.join(RAIZ, rel)
    if not os.path.isfile(ruta):
        return None
    if rel.endswith((".gd", ".gdshader")):
        p = ruta + ".uid"
        return leer(p).strip() if os.path.isfile(p) else None
    if rel.endswith((".tscn", ".tres")):
        m = CAB_RE.match(leer(ruta).split("\n", 1)[0])
        return m.group(1) if m else None
    p = ruta + ".import"
    if os.path.isfile(p):
        m = re.search(r'^uid="([^"]+)"', leer(p), re.M)
        return m.group(1) if m else None
    return None


def todos_los_uid():
    """uid -> conjunto de archivos que lo declaran (para detectar duplicados)."""
    d = {}
    for dp, dn, fn in os.walk(RAIZ):
        dn[:] = [x for x in dn if x not in (".godot", ".git", ".claude")]
        for f in fn:
            ruta = os.path.join(dp, f)
            rel = os.path.relpath(ruta, RAIZ)
            u = None
            if f.endswith(".uid"):
                u = leer(ruta).strip()
                rel = rel[:-4]
            elif f.endswith(".import"):
                m = re.search(r'^uid="([^"]+)"', leer(ruta), re.M)
                u = m.group(1) if m else None
                rel = rel[:-7]
            elif f.endswith((".tscn", ".tres")):
                m = CAB_RE.match(leer(ruta).split("\n", 1)[0])
                u = m.group(1) if m else None
            if u:
                d.setdefault(u, set()).add(rel)
    return d


escenas = sorted(glob.glob("scenes/**/*.tscn", recursive=True)) + ["game.tscn"]
registro = todos_los_uid()
sin_uid = {}  # destino -> nº de referencias que quedan por ruta
total = 0
for esc in escenas:
    texto = leer(esc)
    lineas = texto.split("\n")  # conserva \r si lo hubiera y el final de archivo
    antes = parche = 0
    for i, l in enumerate(lineas):
        if not l.startswith("[ext_resource") or " uid=" in l:
            continue
        m = EXT_RE.match(l)
        if not m:
            print(f"AVISO {esc}: línea no reconocida: {l}")
            continue
        antes += 1
        destino = m.group(3)
        u = uid_de(destino)
        if u is None:
            sin_uid[destino] = sin_uid.get(destino, 0) + 1
            continue
        if not UID_RE.match(u):
            print(f"AVISO {esc}: UID mal formado en {destino}: {u}")
            continue
        if len(registro.get(u, ())) != 1:
            print(f"AVISO {esc}: UID {u} repetido/ausente en el proyecto: {registro.get(u)}")
            continue
        lineas[i] = f'{m.group(1)} uid="{u}" {m.group(2)}'
        parche += 1
    if antes:
        print(f"{esc}\tsin_uid_antes={antes}\tparcheadas={parche}\tquedan={antes - parche}")
    total += parche
    if APLICAR and parche:
        with open(esc, "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(lineas))
print(f"TOTAL parcheadas: {total}  ({'aplicado' if APLICAR else 'simulación'})")
print("Destinos sin UID propio (referencias que quedan solo por ruta):")
for d, n in sorted(sin_uid.items()):
    print(f"  {n}\t{d}")
